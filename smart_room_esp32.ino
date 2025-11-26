#include <WiFi.h>
#include <esp_wifi.h>
#include <Firebase_ESP_Client.h>
#include <addons/TokenHelper.h>
#include <addons/RTDBHelper.h>
#include <DHT.h>

// ==================== 1. CONFIGURATION (DATA ANDA) ====================
#define WIFI_SSID "HONOR X9c"
#define WIFI_PASSWORD "apepulakni"

// Project ID: smart-room-70ea4
#define API_KEY "AIzaSyBa02FAgtc-91aVenSmO9Cr4qLrIG2kkfQ"
#define DATABASE_URL "https://smart-room-70ea4-default-rtdb.asia-southeast1.firebasedatabase.app"

// ==================== 2. PIN DEFINITIONS (HARDWARE ANDA) ====================
#define PIN_DHT 21
#define PIN_TRIG 22
#define PIN_ECHO 23
#define PIN_MQ2 34      // Analog Input

// Relay / Output Pins
#define PIN_BUZZER 25   // Relay 1 (Dikawal Ultrasonic)
#define PIN_LED 26      // Relay 2 (Dikawal Gas/MQ2)

// ==================== 3. OBJECTS & CONSTANTS ====================
#define DHTTYPE DHT11   // Anda guna DHT11

DHT dht(PIN_DHT, DHTTYPE);
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

unsigned long sendDataPrevMillis = 0;
unsigned long readDataPrevMillis = 0;
bool signupOK = false;

// Thresholds (Ikut coding asal anda)
const int DIST_THRESHOLD_CM = 10; // Bawah 10cm -> Buzzer ON
const int GAS_THRESHOLD_VAL = 500; // Atas 500 -> LED ON

// Global Variables
float temp = 0, hum = 0, distance = 0;
int gasLevel = 0;
String currentMode = "auto"; // Default auto
bool lastBuzzerState = false;
bool lastLedState = false;

// Helper function untuk convert string ke lowercase
String toLowerCase(String str) {
  String result = "";
  for (int i = 0; i < str.length(); i++) {
    char c = str.charAt(i);
    if (c >= 'A' && c <= 'Z') {
      result += (char)(c + 32);
    } else {
      result += c;
    }
  }
  return result;
}

void setup() {
  Serial.begin(115200);

  // Init Pins
  pinMode(PIN_TRIG, OUTPUT);
  pinMode(PIN_ECHO, INPUT);
  pinMode(PIN_MQ2, INPUT);
  pinMode(PIN_BUZZER, OUTPUT);
  pinMode(PIN_LED, OUTPUT);

  // Default OFF (Active HIGH: LOW = OFF, HIGH = ON)
  digitalWrite(PIN_BUZZER, LOW);
  digitalWrite(PIN_LED, LOW);
  lastBuzzerState = false;
  lastLedState = false;

  dht.begin();

  // WiFi Connection - Set mode dan improve stability
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.setSleep(false); // Disable WiFi sleep untuk stability
  
  // Set hostname untuk easier identification
  WiFi.setHostname("ESP32-SmartRoom");
  
  // Set power save mode to NONE for better stability
  esp_wifi_set_ps(WIFI_PS_NONE);
  
  Serial.print("Connecting to Wi-Fi: ");
  Serial.println(WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  int wifiTimeout = 0;
  while (WiFi.status() != WL_CONNECTED && wifiTimeout < 40) {
    Serial.print(".");
    delay(500);
    wifiTimeout++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi Connected!");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
    Serial.print("Signal Strength (RSSI): ");
    Serial.print(WiFi.RSSI());
    Serial.println(" dBm");
    
    // Check signal strength
    if (WiFi.RSSI() < -80) {
      Serial.println("WARNING: Weak WiFi signal! Connection may be unstable.");
    }
    
    // Wait a bit for WiFi to stabilize
    delay(2000);
  } else {
    Serial.println("\nWiFi Connection Failed!");
    Serial.println("Please check your WiFi credentials.");
    Serial.println("Will retry in loop()...");
    // Continue anyway, will retry in loop()
  }

  // Firebase Init
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  config.token_status_callback = tokenStatusCallback;

  // CRITICAL: Increase SSL timeout untuk elak SSL errors
  config.timeout.wifiReconnect = 60 * 1000;        // 60 seconds
  config.timeout.socketConnection = 60 * 1000;      // 60 seconds
  config.timeout.sslHandshake = 120 * 1000;       // 120 seconds (CRITICAL untuk SSL)
  config.timeout.serverResponse = 60 * 1000;       // 60 seconds
  
  // Enable WiFi auto reconnect
  Firebase.reconnectWiFi(true);
  
  // CRITICAL: Set buffer size lebih besar untuk SSL
  fbdo.setBSSLBufferSize(8192, 2048); // Rx buffer 8KB, Tx buffer 2KB (increased)
  fbdo.setResponseSize(4096); // Response buffer 4KB (increased)
  
  // CRITICAL: Set keep alive untuk maintain connection
  fbdo.keepAlive(5, 5, 1); // TCP keep alive: idle 5s, interval 5s, count 1

  // Sign up to Firebase
  if (Firebase.signUp(&config, &auth, "", "")) {
    Serial.println("Firebase Auth Success");
    signupOK = true;
  } else {
    Serial.printf("Firebase Auth Error: %s\n", config.signer.signupError.message.c_str());
    Serial.println("Retrying in 5 seconds...");
    delay(5000);
    // Retry once
    if (Firebase.signUp(&config, &auth, "", "")) {
      Serial.println("Firebase Auth Success (Retry)");
      signupOK = true;
    }
  }

  Firebase.begin(&config, &auth);
  
  // Wait for Firebase to be ready
  int retryCount = 0;
  while (!Firebase.ready() && retryCount < 10) {
    Serial.print("Waiting for Firebase... ");
    Serial.println(retryCount + 1);
    delay(1000);
    retryCount++;
  }
  
  if (Firebase.ready()) {
    Serial.println("Firebase Ready!");
  } else {
    Serial.println("Firebase initialization failed!");
  }

  // Initialize mode di Firebase jika belum ada
  if (Firebase.ready() && signupOK) {
    Firebase.RTDB.setString(&fbdo, "/Actuator/mode", "auto");
    Serial.println("Mode initialized to: auto");
  }
}

// Helper Function: Baca Ultrasonic
float getDistance() {
  digitalWrite(PIN_TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(PIN_TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(PIN_TRIG, LOW);
  long duration = pulseIn(PIN_ECHO, HIGH, 30000); // Timeout 30ms supaya tak lag
  if (duration == 0) return 999; // Return large value if no reading
  float dist = duration * 0.034 / 2;
  return dist;
}

// Helper Function: Baca MQ2 (Raw Analog)
int getGasLevel() {
  return analogRead(PIN_MQ2);
}

void loop() {
  // CRITICAL: Check WiFi connection first dengan better handling
  static unsigned long lastWiFiCheck = 0;
  if (millis() - lastWiFiCheck > 2000) { // Check every 2 seconds
    lastWiFiCheck = millis();
    
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("WiFi disconnected! Reconnecting...");
      WiFi.disconnect();
      delay(500);
      WiFi.mode(WIFI_STA);
      WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
      
      int wifiRetry = 0;
      while (WiFi.status() != WL_CONNECTED && wifiRetry < 30) {
        delay(500);
        Serial.print(".");
        wifiRetry++;
      }
      
      if (WiFi.status() == WL_CONNECTED) {
        Serial.println("\nWiFi reconnected!");
        Serial.print("IP: ");
        Serial.println(WiFi.localIP());
        Serial.print("RSSI: ");
        Serial.print(WiFi.RSSI());
        Serial.println(" dBm");
        
        // Reset Firebase connection after WiFi reconnect
        signupOK = false;
        Firebase.begin(&config, &auth);
        delay(2000);
      } else {
        Serial.println("\nWiFi reconnection failed!");
        delay(5000);
        return;
      }
    } else {
      // Check signal strength
      int rssi = WiFi.RSSI();
      if (rssi < -80) {
        Serial.print("Warning: Weak WiFi signal (");
        Serial.print(rssi);
        Serial.println(" dBm)");
      }
    }
  }

  // Check Firebase connection dengan better handling
  if (!Firebase.ready() || !signupOK) {
    static unsigned long lastReconnectAttempt = 0;
    if (millis() - lastReconnectAttempt > 15000) { // Retry every 15 seconds
      lastReconnectAttempt = millis();
      Serial.println("Firebase not ready, attempting reconnect...");
      
      // Reinitialize Firebase - just call begin() again
      Firebase.reconnectWiFi(true);
      delay(1000);
      Firebase.begin(&config, &auth);
      delay(2000);
      
      // Re-signup if needed
      if (!signupOK) {
        if (Firebase.signUp(&config, &auth, "", "")) {
          Serial.println("Firebase Auth Success (Reconnect)");
          signupOK = true;
        } else {
          Serial.printf("Firebase Auth Error: %s\n", config.signer.signupError.message.c_str());
        }
      }
      
      // Check if ready
      int retryCount = 0;
      while (!Firebase.ready() && retryCount < 5) {
        delay(1000);
        retryCount++;
      }
      
      if (Firebase.ready()) {
        Serial.println("Firebase reconnected!");
      } else {
        Serial.println("Firebase reconnection failed!");
      }
    }
    delay(500);
    return;
  }

  // ==================== 1. TERIMA DATA (CTRL APP) ====================
  // Semak setiap 500ms untuk elak terlalu banyak SSL connections
  if (millis() - readDataPrevMillis > 500) {
    readDataPrevMillis = millis();

    // Check connection before operation
    if (WiFi.status() != WL_CONNECTED || !Firebase.ready()) {
      return;
    }

    // 1. Cek Mode (Auto vs Manual) - PASTIKAN CASE INSENSITIVE
    if (Firebase.RTDB.getString(&fbdo, "/Actuator/mode")) {
      if (fbdo.httpCode() == 200) {
        if (fbdo.dataType() == "string") {
          String newMode = toLowerCase(fbdo.stringData());
          newMode.trim();
          
          if (newMode != currentMode && (newMode == "auto" || newMode == "manual")) {
            currentMode = newMode;
            Serial.print("Mode changed to: ");
            Serial.println(currentMode);
          }
        }
      } else if (fbdo.httpCode() != -1) {
        Serial.print("Error reading mode: ");
        Serial.println(fbdo.httpCode());
      }
    }
    delay(100); // Delay between operations

    // 2. Jika MANUAL, ikut arahan Firebase terus (OVERRIDE AUTO)
    if (currentMode == "manual") {
      // Baca status Buzzer dari Firebase
      if (Firebase.RTDB.getInt(&fbdo, "/Actuator/buzzer_status")) {
        if (fbdo.httpCode() == 200 && fbdo.dataType() == "int") {
          int buzzerState = fbdo.intData();
          bool newBuzzerState = (buzzerState == 1);
          if (newBuzzerState != lastBuzzerState) {
            digitalWrite(PIN_BUZZER, newBuzzerState ? HIGH : LOW);
            lastBuzzerState = newBuzzerState;
            Serial.print("Manual Mode - Buzzer: ");
            Serial.println(newBuzzerState ? "ON" : "OFF");
          }
        }
      }
      delay(100); // Delay between operations

      // Baca status LED dari Firebase
      if (Firebase.RTDB.getInt(&fbdo, "/Actuator/led_status")) {
        if (fbdo.httpCode() == 200 && fbdo.dataType() == "int") {
          int ledState = fbdo.intData();
          bool newLedState = (ledState == 1);
          if (newLedState != lastLedState) {
            digitalWrite(PIN_LED, newLedState ? HIGH : LOW);
            lastLedState = newLedState;
            Serial.print("Manual Mode - LED: ");
            Serial.println(newLedState ? "ON" : "OFF");
          }
        }
      }
    }
  }

  // ==================== 2. HANTAR DATA SENSOR & AUTO MODE LOGIC ====================
  // Update setiap 3000ms (3 saat) untuk elak terlalu banyak SSL connections
  if (millis() - sendDataPrevMillis > 3000) {
    sendDataPrevMillis = millis();

    // Check connection before operation
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("WiFi not connected, skipping sensor update");
      return;
    }
    
    if (!Firebase.ready()) {
      Serial.println("Firebase not ready, skipping sensor update");
      return;
    }

    // A. Baca Semua Sensor
    static unsigned long lastDHTRead = 0;
    if (millis() - lastDHTRead > 2000) { // Baca DHT setiap 2 saat (Limit hardware DHT11)
      float t = dht.readTemperature();
      float h = dht.readHumidity();
      if (!isnan(t)) temp = t;
      if (!isnan(h)) hum = h;
      lastDHTRead = millis();
    }

    distance = getDistance();
    gasLevel = getGasLevel();

    // B. Upload ke Firebase (Realtime Database) dengan error handling
    FirebaseJson json;
    json.set("temperature", temp);
    json.set("humidity", hum);
    json.set("distance", distance);
    json.set("gas_level", gasLevel);

    // Retry mechanism untuk send data
    bool sendSuccess = false;
    int retryCount = 0;
    
    while (!sendSuccess && retryCount < 2) {
      if (Firebase.RTDB.setJSON(&fbdo, "/Sensor", &json)) {
        sendSuccess = true;
        // Success - print debug info
        Serial.print("Mode: ");
        Serial.print(currentMode);
        Serial.print(" | Temp: ");
        Serial.print(temp);
        Serial.print(" | Hum: ");
        Serial.print(hum);
        Serial.print(" | Dist: ");
        Serial.print(distance);
        Serial.print(" | Gas: ");
        Serial.println(gasLevel);
      } else {
        // Error handling
        Serial.print("Failed to send sensor data (Attempt ");
        Serial.print(retryCount + 1);
        Serial.print("). Error: ");
        Serial.print(fbdo.errorReason());
        Serial.print(" | HTTP Code: ");
        Serial.println(fbdo.httpCode());
        
        retryCount++;
        if (retryCount < 2) {
          delay(1000); // Wait before retry
        } else {
          // Final failure - try reconnect
          if (fbdo.httpCode() == FIREBASE_ERROR_TCP_ERROR_CONNECTION_REFUSED ||
              fbdo.httpCode() == FIREBASE_ERROR_TCP_ERROR_CONNECTION_LOST ||
              fbdo.httpCode() == -1) {
            Serial.println("Connection error detected. Will reconnect in next cycle...");
            signupOK = false; // Force reconnection
          }
        }
      }
    }
    
    delay(200); // Delay after send operation

    // C. LOGIC AUTO MODE (Hanya jalan jika mode = "auto")
    if (currentMode == "auto") {
      // --- Logic 1: Ultrasonic kawal Buzzer ---
      bool targetBuzzer = (distance > 0 && distance < DIST_THRESHOLD_CM);
      
      // Hanya update jika state berubah
      if (targetBuzzer != lastBuzzerState) {
        digitalWrite(PIN_BUZZER, targetBuzzer ? HIGH : LOW);
        lastBuzzerState = targetBuzzer;
        
        // Update status ke Firebase dengan error handling (only if connection is good)
        if (Firebase.ready() && WiFi.status() == WL_CONNECTED) {
          if (Firebase.RTDB.setInt(&fbdo, "/Actuator/buzzer_status", targetBuzzer ? 1 : 0)) {
            Serial.print("Auto Mode - Buzzer: ");
            Serial.println(targetBuzzer ? "ON (Distance < 10cm)" : "OFF");
          } else {
            // Silent fail untuk actuator updates - hardware sudah update
            // Serial.print("Failed to update buzzer status: ");
            // Serial.println(fbdo.errorReason());
          }
          delay(100); // Delay between Firebase operations
        }
      }

      // --- Logic 2: MQ2 kawal LED ---
      bool targetLed = (gasLevel > GAS_THRESHOLD_VAL);
      
      // Hanya update jika state berubah
      if (targetLed != lastLedState) {
        digitalWrite(PIN_LED, targetLed ? HIGH : LOW);
        lastLedState = targetLed;
        
        // Update status ke Firebase dengan error handling (only if connection is good)
        if (Firebase.ready() && WiFi.status() == WL_CONNECTED) {
          if (Firebase.RTDB.setInt(&fbdo, "/Actuator/led_status", targetLed ? 1 : 0)) {
            Serial.print("Auto Mode - LED: ");
            Serial.print(targetLed ? "ON (Gas > 500)" : "OFF");
            Serial.print(" | Gas Level: ");
            Serial.println(gasLevel);
          } else {
            // Silent fail untuk actuator updates - hardware sudah update
            // Serial.print("Failed to update LED status: ");
            // Serial.println(fbdo.errorReason());
          }
          delay(100); // Delay between Firebase operations
        }
      }
    }
  }
  
  // Small delay at end of loop untuk elak overwhelming the system
  delay(50);
}

