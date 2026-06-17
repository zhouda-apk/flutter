class LlmBackendSettings {
  // Android emulator: http://10.0.2.2:5000
  // Windows/macOS/Chrome app: http://127.0.0.1:5000
  // Physical phone: http://YOUR_COMPUTER_LAN_IP:5000
  static const backendBaseUrl = 'http://172.20.10.2:5000';

  static const mockMode = false;
  static const timeoutSeconds = 90;
}
 
