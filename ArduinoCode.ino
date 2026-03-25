#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <math.h>   // for fabs()
LiquidCrystal_I2C lcd(0x27, 16, 2);

#define BT Serial3   // HM-10 on Mega

// ---------------- Pins ----------------
// ✅ Compressor moved to JD6 = D27
const int PIN_COMPRESS = 27;

// ✅ Inflate valves: JD1,JD3,JD5,JD7
const int INF_PINS[4]   = {22, 24, 26, 28};

// ✅ Deflate valves: JD2,JD4,(T3 removed),JD8
// Put -1 to mean "no valve exists / do nothing"
const int DEF_PINS[4]   = {23, 25, -1, 29};

const int PRESS_PINS[4] = {A0, A1, A2, A3};

// Active LOW relay board
const int RELAY_ON  = LOW;
const int RELAY_OFF = HIGH;

// ---------------- Caps ----------------
const float PSI_MAX_CAP = 45.0;  // inflate cap only

// ---------------- Sensor calibration ----------------
const float VREF  = 5.0;
const float V_MIN = 0.5;
const float V_MAX = 4.5;
const float PSI_SENSOR_MAX = 150.0;

// Oversampling
const int OVERSAMPLE_N = 8;          // number of ADC samples
const int OVERSAMPLE_DELAY_MS = 2;   // delay between samples

// Filtering
float psiFiltered[4] = {0,0,0,0};
const float FILTER_ALPHA = 0.15;

// Raw + display PSI
float psiTire[4]        = {0,0,0,0};
float psiTireDisplay[4] = {0,0,0,0};

// ---------------- State machine ----------------
enum Mode { IDLE, INFLATING, DEFLATING };
Mode mode = IDLE;

int activeTire = -1;  // 0..3
bool running = false;

// ---------------- Relay settle window ----------------
unsigned long lastSwitchMs = 0;
const unsigned long SENSOR_SETTLE_MS = 300;

// ---------------- BLE buffer ----------------
String btBuffer = "";
unsigned long lastCharTime = 0;
const unsigned long MSG_TIMEOUT = 120;

// LCD + BLE tick
unsigned long lastTick = 0;
const unsigned long TICK_PERIOD = 500;

// ---------------- Leak detection ----------------
bool leakArmed[4] = {false,false,false,false};
unsigned long leakStartMs[4] = {0,0,0,0};
float leakStartPsi[4] = {0,0,0,0};

const unsigned long LEAK_WINDOW_MS = 15000;
const float LEAK_DROP_PSI = 1.0;

const unsigned long LEAK_SETTLE_MS = 2000;
unsigned long idleSinceMs = 0;

// NEW: valve pre-open delay before compressor
const unsigned long VALVE_PREOPEN_MS = 1000; // 1 second

// ----------------------------------
// Helpers
// ----------------------------------
void showLCD(const String &l1, const String &l2 = "") {
  lcd.clear();
  lcd.setCursor(0,0); lcd.print(l1);
  lcd.setCursor(0,1); lcd.print(l2);
}

void allOff() {
  for (int i=0;i<4;i++) {
    digitalWrite(INF_PINS[i], RELAY_OFF);

    // ✅ Only write deflate pin if it exists (not -1)
    if (DEF_PINS[i] != -1) {
      digitalWrite(DEF_PINS[i], RELAY_OFF);
    }
  }
  digitalWrite(PIN_COMPRESS, RELAY_OFF);
}

void resetLeakBaselines() {
  for (int i=0;i<4;i++) leakArmed[i] = false;
  idleSinceMs = millis();
}

void applyControl(int tireIdx, Mode newMode) {
  allOff();
  delay(40);                 // dead-time for safety
  lastSwitchMs = millis();   // start settle window

  activeTire = tireIdx;
  mode = newMode;
  running = (newMode != IDLE);

  if (newMode == INFLATING) {

    // 1️⃣ Open inflation valve first (JD1/JD3/JD5/JD7)
    digitalWrite(INF_PINS[tireIdx], RELAY_ON);
    showLCD("T"+String(tireIdx+1)+" INFLATE", "Valve open");

    // 2️⃣ Wait 1 second so valve is fully open
    delay(VALVE_PREOPEN_MS);

    // 3️⃣ Start compressor (JD6)
    digitalWrite(PIN_COMPRESS, RELAY_ON);
    showLCD("T"+String(tireIdx+1)+" INFLATE", "Valve + COMP");
  }
  else if (newMode == DEFLATING) {

    // ✅ Tire 3 deflation removed/blocked (index 2)
    if (tireIdx == 2 || DEF_PINS[tireIdx] == -1) {
      running = false;
      mode = IDLE;
      showLCD("T3 DEF DISABLED", "Valve removed");
      BT.println("WARN:DEF_DISABLED:T3");
      resetLeakBaselines();
      return;
    }

    digitalWrite(DEF_PINS[tireIdx], RELAY_ON);
    showLCD("T"+String(tireIdx+1)+" DEFLATE", "DEF ON");
  }
  else {
    showLCD("ALL OFF", "Idle mode");
    resetLeakBaselines();
  }
}

// Oversampled ADC -> PSI
float readPressurePsi(int idx) {
  long sumRaw = 0;

  for (int k=0; k<OVERSAMPLE_N; k++) {
    sumRaw += analogRead(PRESS_PINS[idx]);
    delay(OVERSAMPLE_DELAY_MS);
  }

  float rawAvg = sumRaw / (float)OVERSAMPLE_N;
  float v = (rawAvg / 1023.0) * VREF;
  v = constrain(v, V_MIN, V_MAX);

  float psi = (v - V_MIN) * (PSI_SENSOR_MAX / (V_MAX - V_MIN));

  // Low-pass filter
  psiFiltered[idx] += FILTER_ALPHA * (psi - psiFiltered[idx]);
  return psiFiltered[idx];
}

float round1(float x) {
  return floor(x*10.0 + 0.5) / 10.0;
}

// BLE send (uses display PSI)
void sendPsiAll() {
  for (int i=0;i<4;i++) {
    BT.print("PSI:");
    BT.print(i+1);
    BT.print(":");
    BT.println(psiTireDisplay[i], 1);
    delay(6);
  }
}

// Leak detection (paused during settle)
void checkLeakAll() {
  if (running) return;
  if (millis() - idleSinceMs < LEAK_SETTLE_MS) return;
  if (millis() - lastSwitchMs < SENSOR_SETTLE_MS) return;

  for (int i=0;i<4;i++) {

    // 🚫 Disable leak detection for Tire 3 (index 2)
    if (i == 2) continue;

    float currentPsi = psiTireDisplay[i];

    if (!leakArmed[i]) {
      leakArmed[i] = true;
      leakStartMs[i] = millis();
      leakStartPsi[i] = currentPsi;
      continue;
    }

    if (millis() - leakStartMs[i] >= LEAK_WINDOW_MS) {
      float drop = leakStartPsi[i] - currentPsi;

      if (drop > LEAK_DROP_PSI) {
        BT.print("ALERT:LEAK:");
        BT.print(i+1);
        BT.print(":");
        BT.println(drop, 2);

        showLCD("LEAK DETECTED!", "T"+String(i+1)+" -" + String(drop,1)+"psi");
      }

      leakStartMs[i] = millis();
      leakStartPsi[i] = currentPsi;
    }
  }
}

// Parse commands: Tn:I / Tn:D / Tn:S
void handleCommand(String cmd) {
  cmd.trim();
  if (!cmd.startsWith("T")) return;
  if (cmd.length() < 4 || cmd.charAt(2) != ':') return;

  int tireNum = cmd.substring(1,2).toInt();
  if (tireNum < 1 || tireNum > 4) return;

  int idx = tireNum - 1;
  String action = cmd.substring(3);
  action.trim();

  // If running on a tire, ignore commands for other tires
  if (running && idx != activeTire) return;

  if (action == "I") applyControl(idx, INFLATING);
  else if (action == "D") {
    // ✅ Block Tire 3 deflate immediately (extra safety)
    if (idx == 2) {
      BT.println("WARN:DEF_DISABLED:T3");
      showLCD("T3 DEF DISABLED", "Valve removed");
      return;
    }
    applyControl(idx, DEFLATING);
  }
  else if (action == "S") {
    applyControl(idx, IDLE);
    BT.print("EVENT:STOP:");
    BT.println(idx+1);
  }
}

void setup() {
  Serial.begin(9600);
  BT.begin(9600);

  pinMode(PIN_COMPRESS, OUTPUT);
  for (int i=0;i<4;i++) {
    pinMode(INF_PINS[i], OUTPUT);

    // ✅ only set pinMode if deflate pin exists
    if (DEF_PINS[i] != -1) {
      pinMode(DEF_PINS[i], OUTPUT);
    }
  }

  allOff();  // guarantee OFF at boot

  lcd.begin();
  lcd.backlight();
  showLCD("System Ready", "Idle mode");

  resetLeakBaselines();

  // prime filter with first stable read
  for (int i=0;i<4;i++) {
    psiFiltered[i] = readPressurePsi(i);
    psiTire[i] = psiFiltered[i];
    psiTireDisplay[i] = round1(psiTire[i]);
  }
}

void loop() {
  // -------- BLE input --------
  while (BT.available()) {
    char c = BT.read();
    btBuffer += c;
    lastCharTime = millis();
  }
  if (btBuffer.length() > 0 && millis() - lastCharTime > MSG_TIMEOUT) {
    handleCommand(btBuffer);
    btBuffer = "";
  }

  // -------- Read sensors (unless in settle window) --------
  bool inSettle = (millis() - lastSwitchMs < SENSOR_SETTLE_MS);

  if (!inSettle) {
    for (int i=0;i<4;i++) {
      float newPsi = readPressurePsi(i);

      // 🔧 Extra protection for Tire 3 (index 2)
      if (i == 2) {
        if (fabs(newPsi - psiTire[i]) > 3.0) {
          // ignore jump
        } else {
          psiTire[i] = newPsi;
        }
      } else {
        psiTire[i] = newPsi;
      }

      psiTireDisplay[i] = round1(psiTire[i]);
    }
  }

  // -------- Inflate cap ONLY --------
  if (running && activeTire >= 0 && !inSettle) {
    if (mode == INFLATING && psiTireDisplay[activeTire] >= PSI_MAX_CAP) {
      applyControl(activeTire, IDLE);
      BT.print("EVENT:CAP_MAX:");
      BT.println(activeTire+1);
    }
  }

  // -------- Leak detection --------
  checkLeakAll();

  // -------- Synced LCD + BLE tick --------
  if (millis() - lastTick >= TICK_PERIOD) {
    lastTick = millis();

    sendPsiAll(); // BLE uses same display values

    lcd.setCursor(0,0);
    if (activeTire >= 0) {
      lcd.print("Tire Active     ");
      lcd.setCursor(0,1);
      lcd.print("T");
      lcd.print(activeTire+1);
      lcd.print(" PSI=");
      lcd.print(psiTireDisplay[activeTire], 1);
      lcd.print("   ");
    } else {
      lcd.print("Idle Monitoring ");
      lcd.setCursor(0,1);
      lcd.print("T1 PSI=");
      lcd.print(psiTireDisplay[0], 1);
      lcd.print("       ");
    }
  }
}
