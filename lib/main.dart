import 'package:flutter/material.dart';
import 'package:vad/vad.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Activity Detection',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: VoiceDetectionScreen(),
    );
  }
}

class VoiceDetectionScreen extends StatefulWidget {
  @override
  _VoiceDetectionScreenState createState() => _VoiceDetectionScreenState();
}

class _VoiceDetectionScreenState extends State<VoiceDetectionScreen> {
  late VadHandlerBase _vadHandler;
  bool _isListening = false;
  bool _isInitialized = false;
  List<VoiceEvent> _voiceEvents = [];

  @override
  void initState() {
    super.initState();
    _initializeVAD();
  }

  Future<void> _initializeVAD() async {
    try {
      // Check current permission status first
      var status = await Permission.microphone.status;
      
      if (status == PermissionStatus.denied) {
        // Request permission if denied
        status = await Permission.microphone.request();
      }
      
      if (status == PermissionStatus.permanentlyDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Microphone permission permanently denied. Please enable it in app settings.'),
            action: SnackBarAction(
              label: 'Open Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
        return;
      }
      
      if (status != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Microphone permission is required')),
        );
        return;
      }

      // Initialize VAD handler
      _vadHandler = VadHandler.create(isDebug: true);
      
      // Set up voice activity listeners
      _vadHandler.onSpeechStart.listen((_) {
        setState(() {
          _voiceEvents.add(VoiceEvent(
            type: VoiceEventType.started,
            timestamp: DateTime.now(),
          ));
        });
        debugPrint('Speech started at ${DateTime.now()}');
      });

      _vadHandler.onSpeechEnd.listen((List<double> samples) {
        setState(() {
          _voiceEvents.add(VoiceEvent(
            type: VoiceEventType.stopped,
            timestamp: DateTime.now(),
          ));
        });
        debugPrint('Speech ended at ${DateTime.now()}');
      });

      _vadHandler.onRealSpeechStart.listen((_) {
        debugPrint('Real speech start detected (not a misfire).');
      });

      _vadHandler.onVADMisfire.listen((_) {
        debugPrint('VAD misfire detected.');
      });

      _vadHandler.onError.listen((String message) {
        debugPrint('VAD Error: $message');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('VAD Error: $message')),
        );
      });

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize VAD: $e')),
      );
    }
  }

  Future<void> _startListening() async {
    if (!_isInitialized) return;

    try {
      _vadHandler.startListening(
        frameSamples: 512,
        minSpeechFrames: 8,
        preSpeechPadFrames: 30,
        redemptionFrames: 24,
        positiveSpeechThreshold: 0.5,
        negativeSpeechThreshold: 0.35,
        submitUserSpeechOnPause: false,
        model: 'v5',
      );
      
      setState(() {
        _isListening = true;
        _voiceEvents.clear(); // Clear previous events when starting
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start listening: $e')),
      );
    }
  }

  Future<void> _stopListening() async {
    try {
      _vadHandler.stopListening();
      setState(() {
        _isListening = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to stop listening: $e')),
      );
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
           '${timestamp.minute.toString().padLeft(2, '0')}:'
           '${timestamp.second.toString().padLeft(2, '0')}.'
           '${timestamp.millisecond.toString().padLeft(3, '0')}';
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _vadHandler.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Voice Activity Detection'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Status indicator
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isListening ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isListening ? Colors.green : Colors.grey,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isListening ? Icons.mic : Icons.mic_off,
                    color: _isListening ? Colors.green : Colors.grey,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    _isListening ? 'Listening for voice activity...' : 'Not listening',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _isListening ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 20),
            
            // Start/Stop button
            ElevatedButton(
              onPressed: _isInitialized
                  ? (_isListening ? _stopListening : _startListening)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isListening ? Colors.red : Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _isListening ? 'Stop Listening' : 'Start Listening',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),

            SizedBox(height: 10),

            // Permission button
            TextButton.icon(
              onPressed: () async {
                var status = await Permission.microphone.status;
                
                if (status == PermissionStatus.denied || status == PermissionStatus.permanentlyDenied) {
                  status = await Permission.microphone.request();
                }
                
                String message;
                SnackBarAction? action;
                
                switch (status) {
                  case PermissionStatus.granted:
                    message = 'Microphone permission granted!';
                    // Try to initialize VAD if not already done
                    if (!_isInitialized) {
                      _initializeVAD();
                    }
                    break;
                  case PermissionStatus.denied:
                    message = 'Microphone permission denied';
                    break;
                  case PermissionStatus.permanentlyDenied:
                    message = 'Permission permanently denied. Open app settings to enable.';
                    action = SnackBarAction(
                      label: 'Settings',
                      onPressed: () => openAppSettings(),
                    );
                    break;
                  case PermissionStatus.restricted:
                    message = 'Microphone access is restricted';
                    break;
                  case PermissionStatus.limited:
                    message = 'Microphone access is limited';
                    break;
                  case PermissionStatus.provisional:
                    message = 'Microphone permission is provisional';
                    break;
                }
                
                debugPrint("Microphone permission status: $status");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    action: action,
                  ),
                );
              },
              icon: const Icon(Icons.settings_voice),
              label: const Text("Check/Request Microphone Permission"),
            ),
            
            SizedBox(height: 20),
            
            // Events list header
            if (_voiceEvents.isNotEmpty)
              Text(
                'Voice Activity Log',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            
            SizedBox(height: 10),
            
            // Events list
            Expanded(
              child: _voiceEvents.isEmpty
                  ? Center(
                      child: Text(
                        _isListening
                            ? 'Waiting for voice activity...'
                            : 'Press "Start Listening" to begin voice detection',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _voiceEvents.length,
                      itemBuilder: (context, index) {
                        final event = _voiceEvents[index];
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: Icon(
                              event.type == VoiceEventType.started
                                  ? Icons.play_arrow
                                  : Icons.stop,
                              color: event.type == VoiceEventType.started
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            title: Text(
                              event.type == VoiceEventType.started
                                  ? 'Voice Started'
                                  : 'Voice Stopped',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              _formatTimestamp(event.timestamp),
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            trailing: Text(
                              '#${index + 1}',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class VoiceEvent {
  final VoiceEventType type;
  final DateTime timestamp;

  VoiceEvent({
    required this.type,
    required this.timestamp,
  });
}

enum VoiceEventType {
  started,
  stopped,
}