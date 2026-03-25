# Smart Automatic Tire Inflation & Deflation System 🚗💨

## 📌 Overview
This project presents the design and development of an Automatic Tire Inflation and Deflation System that helps drivers maintain correct tire pressure in a safe and efficient way.

This work was completed as a graduation project at King Fahd University of Petroleum & Minerals.

The system is implemented as a portable prototype and uses a 12 V air compressor, solenoid valves, and pressure and temperature sensors controlled by a microcontroller. It connects wirelessly to a mobile application, allowing users to set target pressures and monitor real-time readings.

The system also includes a leak detection feature that identifies sudden pressure drops and alerts the user.

---

## 🚀 What the System Does
- Automatically inflates and deflates each tire to a target pressure  
- No physical effort is required, all operations are controlled through the mobile application  
- Monitors tire pressure and temperature in real time  
- Detects sudden pressure drops and alerts the user  
- Provides continuous tire condition monitoring  
- Improves safety by maintaining proper tire pressure  

---

## 🧪 System Testing
The system was tested using a setup connected to four tires as part of the prototype validation.

During testing, the system successfully:
- Adjusted tire pressure within the required range  
- Maintained pressure accuracy within ±1 PSI  
- Provided real-time sensor readings  
- Detected abnormal pressure drops for leak detection  

The results demonstrated that the system meets its functional requirements and operates reliably.

---

## 🏫 Project Demonstration
The project was presented at the Senior Projects Expo at King Fahd University of Petroleum & Minerals.

The demonstration included:
- Live operation of the prototype system  
- Real-time pressure monitoring through the mobile application  
- Automatic inflation and deflation of four tires  
- Presentation of system design and functionality  

---

## 🛠️ Hardware Components
The system is built using a combination of electrical, mechanical, and control components that work together to manage airflow and monitor tire conditions.

### Main Components
- Arduino Mega 2560 as the main controller  
- Tire Pressure Monitoring System sensors for pressure readings  
- Bluetooth module HM-10 for wireless communication  
- DC-DC converter for voltage regulation  
- 5 V and 12 V battery supply  

### Air System Components
- 12 V air compressor for inflation  
- Aluminum air manifold for distributing airflow  
- Solenoid valves (2/2) to control air direction  
- Check valve to prevent backflow  
- Air hoses for air transfer  
- Quick connect couplers for easy attachment to tires  
- Hose clamps to secure connections  

### Supporting Components
- Breadboard for circuit prototyping  
- Electrical wires for connections  

All components are integrated into a portable system that allows controlled inflation and deflation of multiple tires while ensuring stable operation and reliable performance.

---

## 💻 Software and Control
The system uses a feedback control approach. Sensor readings are continuously compared with the target pressure set by the user.

Based on this comparison:
- The compressor is activated for inflation  
- Valves are used for deflation  
- The system stops automatically once the target pressure is reached  

The mobile application allows users to:
- Set target pressure values  
- Monitor real-time data  
- Receive alerts  

All operations are performed through the application without manual interaction with the tires.

---

## ⚙️ How It Works
1. The user sets the desired pressure using the mobile application  
2. Sensors measure pressure and temperature  
3. The controller processes the readings  
4. The system inflates or deflates as required  
5. The system stops automatically at the target pressure  
6. Alerts are generated if abnormal pressure drops are detected  

---

## 🔒 Safety Features
- Automatic shutoff if pressure exceeds safe limits  
- Electrical protection using fuses  
- Emergency stop functionality  
- Monitoring of system faults  

---

## 📊 Performance
- Pressure adjustment within a few minutes  
- Accuracy of approximately ±1 PSI  
- Real-time updates from sensors  
- Operation based on a 12 V power system  

---

## 🌍 Applications
- Everyday drivers  
- Off-road driving scenarios  
- Situations where manual tire inflation is difficult  
- Automotive workshops  

---

## 🔮 Future Improvements
- Predictive leak detection using data analysis  
- Integration with vehicle systems  
- Enhanced mobile application features  

---

## 👨‍💻 Team
- Hussain Alhaddad – Electrical Engineering  
- Fahad Alfaris – Electrical Engineering  
- Hadi Almayyad – Mechanical Engineering  
- Murtadha Alghadban – Computer Science  

---

## 📝 Note
This project was developed as a graduation project at King Fahd University of Petroleum & Minerals and demonstrates a practical approach to automating tire pressure management using sensing, control, and wireless communication.
