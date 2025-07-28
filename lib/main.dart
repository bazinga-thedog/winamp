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
  VadHandlerBase? _vadHandler;
  bool _isListening = false;
  bool _isInitialized = false;
  bool _permissionGranted = false;
  List<VoiceEvent> _voiceEvents = [];
  String _statusMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _requestPermissionAndInitialize();
  }

  Future<void> _requestPermissionAndInitialize() async {
    setState(() {
      _statusMessage = 'Requesting microphone permission...';
    });

    try {
      // Check and request microphone permission
      var status = await Permission.microphone.status;
      
      if (status == PermissionStatus.denied) {
        status = await Permission.microphone.request();
      }
      
      if (status == PermissionStatus.permanentlyDenied) {
        setState(() {
          _statusMessage = 'Permission permanently denied. Please enable in settings.';
        });
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
        setState(() {
          _statusMessage = 'Microphone permission required';
        });
        return;
      }

      setState(() {
        _permissionGranted = true;
        _statusMessage = 'Initializing VAD...';
      });

      await _initializeVAD();
      
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to initialize: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize: $e')),
      );
    }
  }

  Future<void> _initializeVAD() async {
    try {
      // Create VAD handler
      _vadHandler = VadHandler.create(isDebug: true);
      
      // Set up all event listeners before starting
      _vadHandler!.onSpeechStart.listen((_) {
        if (mounted) {
          setState(() {
            _voiceEvents.add(VoiceEvent(
              type: VoiceEventType.started,
              timestamp: DateTime.now(),
            ));
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎤 Speech started'),
              duration: Duration(milliseconds: 800),
              backgroundColor: Colors.green,
            ),
          );
        }
      });

      _vadHandler!.onSpeechEnd.listen((List<double> samples) {
        if (mounted) {
          setState(() {
            _voiceEvents.add(VoiceEvent(
              type: VoiceEventType.stopped,
              timestamp: DateTime.now(),
            ));
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🔇 Speech ended (${samples.length} samples)'),
              duration: Duration(milliseconds: 800),
              backgroundColor: Colors.red,
            ),
          );
        }
      });

      _vadHandler!.onRealSpeechStart.listen((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Real speech confirmed'),
              duration: Duration(milliseconds: 1000),
              backgroundColor: Colors.blue,
            ),
          );
        }
      });

      _vadHandler!.onVADMisfire.listen((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ VAD misfire detected'),
              duration: Duration(milliseconds: 1000),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });

      _vadHandler!.onFrameProcessed.listen((frameData) {
        // This gives real-time feedback about speech probability
        // You can uncomment this to see frame-by-frame processing
        // print('Speech probability: ${frameData.isSpeech}, Not speech: ${frameData.notSpeech}');
      });

      _vadHandler!.onError.listen((String message) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ VAD Error: $message'),
              backgroundColor: Colors.red[700],
              duration: Duration(seconds: 3),
            ),
          );
        }
      });

      setState(() {
        _isInitialized = true;
        _statusMessage = 'Ready to start listening';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 VAD initialized successfully!'),
          backgroundColor: Colors.green[600],
          duration: Duration(seconds: 2),
        ),
      );

    } catch (e) {
      setState(() {
        _statusMessage = 'VAD initialization failed: $e';
      });
      print('VAD initialization error: $e');
    }
  }

  Future<void> _startListening() async {
    if (!_isInitialized || _vadHandler == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('VAD not initialized yet')),
      );
      return;
    }

    try {
      // Clear previous events when starting fresh
      setState(() {
        _voiceEvents.clear();
        _statusMessage = 'Starting to listen...';
      });

      // Start VAD with optimized parameters for better detection
      _vadHandler!.startListening(
        positiveSpeechThreshold: 0.5,    // Lower = more sensitive to speech
        negativeSpeechThreshold: 0.35,   // Higher = less likely to stop during pauses
        preSpeechPadFrames: 1,           // Frames before speech detection
        redemptionFrames: 8,             // Frames to wait before ending speech
        frameSamples: 1536,              // Samples per frame (96ms at 16kHz)
        minSpeechFrames: 3,              // Minimum frames to confirm speech
        submitUserSpeechOnPause: false,  // Don't submit on pause
        model: 'legacy',                 // Use legacy model (more stable)
      );
      
      setState(() {
        _isListening = true;
        _statusMessage = 'Listening for voice activity...';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎧 Started listening for speech'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );

    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to start listening: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start listening: $e')),
      );
    }
  }

  Future<void> _stopListening() async {
    if (_vadHandler == null) return;

    try {
      _vadHandler!.stopListening();
      setState(() {
        _isListening = false;
        _statusMessage = 'Stopped listening';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏹️ Stopped listening'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 1),
        ),
      );

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
    if (_vadHandler != null) {
      try {
        _vadHandler!.dispose();
      } catch (e) {
        print('Error disposing VAD handler: $e');
      }
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
                color: _isListening 
                    ? Colors.green.withOpacity(0.1) 
                    : _isInitialized 
                        ? Colors.blue.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isListening 
                      ? Colors.green 
                      : _isInitialized 
                          ? Colors.blue
                          : Colors.grey,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isListening 
                        ? Icons.mic 
                        : _isInitialized 
                            ? Icons.mic_off 
                            : Icons.settings_voice,
                    color: _isListening 
                        ? Colors.green 
                        : _isInitialized 
                            ? Colors.blue
                            : Colors.grey,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _isListening 
                            ? Colors.green 
                            : _isInitialized 
                                ? Colors.blue
                                : Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 20),
            
            // Control buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isInitialized && _permissionGranted
                        ? (_isListening ? _stopListening : _startListening)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isListening ? Colors.red : Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _isListening ? 'Stop Listening' : 'Start Listening',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => _requestPermissionAndInitialize(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Icon(Icons.refresh),
                ),
              ],
            ),
            
            SizedBox(height: 20),
            
            // Events list header
            if (_voiceEvents.isNotEmpty)
              Text(
                'Voice Activity Log (${_voiceEvents.length} events)',
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isListening ? Icons.hearing : Icons.mic_off,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            _isListening
                                ? 'Listening... Try speaking now!'
                                : _isInitialized
                                    ? 'Press "Start Listening" to begin voice detection'
                                    : 'Initializing voice detection...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _voiceEvents.length,
                      itemBuilder: (context, index) {
                        final event = _voiceEvents[index];
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 4),
                          elevation: 2,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: event.type == VoiceEventType.started
                                  ? Colors.green
                                  : Colors.red,
                              child: Icon(
                                event.type == VoiceEventType.started
                                    ? Icons.play_arrow
                                    : Icons.stop,
                                color: Colors.white,
                              ),
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
                                fontWeight: FontWeight.bold,
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