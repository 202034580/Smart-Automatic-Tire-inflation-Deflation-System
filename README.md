# Smart Automatic Tire Inflation & Deflation System 🚗💨

## 📌 Overview
The **Smart Automatic Tire Inflation and Deflation System** is an intelligent automotive solution designed to automate tire pressure management, improve road safety, and reduce manual effort for drivers.

The system enables automatic inflation and deflation of tires, real-time monitoring, and early detection of leaks using a combination of sensors, embedded systems, and a mobile application.

The project was successfully developed and demonstrated as a **Senior Design Project at King Fahd University of Petroleum & Minerals (KFUPM)** and showcased at the **Senior Projects Expo**.

---

## 🎯 Objectives
- Automate tire pressure adjustment for different driving conditions
- Improve safety by maintaining optimal tire pressure
- Reduce driver effort and dependency on manual tools
- Provide real-time monitoring and intelligent alerts
- Enable future integration with smart vehicle systems

---

## 🚀 Key Features
- 🔄 Automatic inflation and deflation (per tire control)
- 📊 Real-time pressure & temperature monitoring
- ⚠️ Intelligent leak detection system
- 📱 Mobile app control via Bluetooth Low Energy (BLE)
- 🎯 Custom pressure settings for each tire
- 🧠 Smart feedback system with alerts
- 🔒 Built-in safety mechanisms (auto shutoff, fault detection)

---

## 🧪 System Testing & Validation
The system was fully tested on a **four-tire setup**, simulating real vehicle conditions.

### ✔️ Testing Highlights:
- Simultaneous connection to **4 tires**
- Achieved pressure adjustment of **±15 PSI within 3–5 minutes**
- Maintained accuracy of **±1 PSI**
- Verified real-time sensor updates (≤1 second delay)
- Successfully detected **abnormal pressure drops (leaks)**
- Stable operation under continuous testing conditions

The testing phase validated the system’s:
- Reliability ✅
- Accuracy ✅
- Safety performance ✅
- Real-world applicability ✅

---

## 🏫 Project Demonstration
The project was officially presented at:

**King Fahd University of Petroleum & Minerals (KFUPM) – Senior Projects Expo**

### 🎤 Demonstration Included:
- Live system operation on prototype cart
- Real-time pressure monitoring via mobile app
- Automatic inflation and deflation of 4 tires
- Leak detection alerts demonstration
- Explanation of system architecture and engineering design

The project received positive feedback for:
- Innovation 💡
- Practicality 🚗
- Integration of multiple engineering disciplines ⚙️

---

## 🛠️ System Architecture

### 🔌 Hardware Components
- Arduino Mega 2560 (Main Controller)
- 12V Air Compressor (540W)
- Solenoid Valves (2/2 & 3/2)
- Pressure Sensors (±1 PSI accuracy)
- Temperature Sensors
- Bluetooth Module (HM-10 BLE)
- Power Distribution System (fuses, relays, MOSFETs)
- Portable mechanical frame (cart-based system)

---

### ⚙️ Software Components
- Embedded C/C++ (Arduino)
- Mobile Application (Bluetooth communication)
- Control algorithms (feedback-based system)
- Data processing and filtering (sensor readings)

---

## ⚙️ How the System Works
1. User sets desired tire pressure using the mobile app.
2. Sensors continuously measure pressure & temperature.
3. Arduino processes data and compares with target values.
4. System actions:
   - Inflate → Compressor ON + valve open
   - Deflate → Vent valve open
5. System automatically stops at target pressure.
6. If abnormal pressure drop detected → 🚨 Alert sent to user.

---

## 📱 Mobile Application Features
- Set pressure for each tire individually
- Select driving modes:
  - Highway
  - Off-road (Sand)
  - Custom mode
- Display live sensor readings
- Show alerts (leaks, overpressure, faults)
- User-friendly interface with minimal steps

---

## 🔐 Safety Features
- Automatic shutoff above **50 PSI**
- Emergency stop button
- Overcurrent protection (main fuse + branch fuses)
- Reverse polarity protection
- Thermal protection for compressor
- Fault detection and safe shutdown

---

## 📊 Performance Specifications
| Feature | Value |
|--------|------|
| Pressure Adjustment | ±15 PSI |
| Time | 3–5 minutes (4 tires) |
| Accuracy | ±1 PSI |
| Sensor Update Rate | ≤1 second |
| Airflow | ≥70 L/min |
| Power Source | 12V DC |

---

## 🌍 Applications
- Everyday drivers 🚗
- Off-road enthusiasts 🏜️
- Elderly & disabled users ♿
- Automotive workshops 🔧
- Smart vehicle systems (future integration)

---

## 💡 Future Improvements
- AI-based predictive tire maintenance
- Integration with vehicle CAN systems
- Cloud data storage & analytics
- Automatic terrain detection
- Compact in-vehicle version (next phase)

---

## 👨‍💻 Team Members
- Hussain Alhaddad (Electrical Engineering)
- Fahad Alfaris (Electrical Engineering)
- Hadi Almayyad (Mechanical Engineering)
- Murtadha Alghadban (Computer Science)

---

## 📄 License
This project is developed for academic purposes under KFUPM Senior Design Program.
