import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vad/vad.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Activity Detection',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const VoiceDetectionScreen(),
    );
  }
}

class VoiceDetectionScreen extends StatefulWidget {
  const VoiceDetectionScreen({super.key});

  @override
  State<VoiceDetectionScreen> createState() => _VoiceDetectionScreenState();
}

class _VoiceDetectionScreenState extends State<VoiceDetectionScreen> {
  final _vadHandler = VadHandler.create(isDebug: true);
  bool isListening = false;
  final List<VoiceEvent> voiceEvents = [];

  @override
  void initState() {
    super.initState();
    _setupVadHandler();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.microphone.request();
    debugPrint("Initial microphone permission status: $status");

    if (status == PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Microphone permission granted automatically!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _setupVadHandler() {
    // Add debug prints to see if events are being set up
    debugPrint("Setting up VAD handler...");

    _vadHandler.onSpeechStart.listen((_) {
      debugPrint('🎤 Speech detected at ${DateTime.now()}');
      setState(() {
        voiceEvents.add(VoiceEvent(
          type: VoiceEventType.started,
          timestamp: DateTime.now(),
          message: 'Speech detected.',
        ));
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎤 Speech started'),
            duration: Duration(milliseconds: 800),
            backgroundColor: Colors.green,
          ),
        );
      }
    });

    _vadHandler.onRealSpeechStart.listen((_) {
      debugPrint(
          '✅ Real speech start detected (not a misfire) at ${DateTime.now()}');
      setState(() {
        voiceEvents.add(VoiceEvent(
          type: VoiceEventType.realSpeech,
          timestamp: DateTime.now(),
          message: 'Real speech start detected (not a misfire).',
        ));
      });
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

    _vadHandler.onSpeechEnd.listen((List<double> samples) {
      debugPrint(
          '🔇 Speech ended at ${DateTime.now()}, samples: ${samples.length}');
      setState(() {
        voiceEvents.add(VoiceEvent(
          type: VoiceEventType.stopped,
          timestamp: DateTime.now(),
          message: 'Speech ended, samples: ${samples.length}',
        ));
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔇 Speech ended (${samples.length} samples)'),
            duration: Duration(milliseconds: 800),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    _vadHandler.onFrameProcessed.listen((frameData) {
      // Only log every 50th frame to avoid spam
      if (DateTime.now().millisecondsSinceEpoch % 50 == 0) {
        final isSpeech = frameData.isSpeech;
        final notSpeech = frameData.notSpeech;
        debugPrint('📊 Frame: Speech=$isSpeech, NotSpeech=$notSpeech');
      }
    });

    _vadHandler.onVADMisfire.listen((_) {
      debugPrint('⚠️ VAD misfire detected at ${DateTime.now()}');
      setState(() {
        voiceEvents.add(VoiceEvent(
          type: VoiceEventType.misfire,
          timestamp: DateTime.now(),
          message: 'VAD misfire detected.',
        ));
      });
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

    _vadHandler.onError.listen((String message) {
      debugPrint('❌ VAD Error: $message');
      setState(() {
        voiceEvents.add(VoiceEvent(
          type: VoiceEventType.error,
          timestamp: DateTime.now(),
          message: 'Error: $message',
        ));
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $message'),
            backgroundColor: Colors.red[700],
            duration: Duration(seconds: 3),
          ),
        );
      }
    });

    debugPrint("VAD handler setup complete");
  }

  @override
  void dispose() {
    _vadHandler.dispose();
    super.dispose();
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}.'
        '${timestamp.millisecond.toString().padLeft(3, '0')}';
  }

  Color _getEventColor(VoiceEventType type) {
    switch (type) {
      case VoiceEventType.started:
        return Colors.green;
      case VoiceEventType.stopped:
        return Colors.red;
      case VoiceEventType.realSpeech:
        return Colors.blue;
      case VoiceEventType.misfire:
        return Colors.orange;
      case VoiceEventType.error:
        return Colors.red[700]!;
    }
  }

  IconData _getEventIcon(VoiceEventType type) {
    switch (type) {
      case VoiceEventType.started:
        return Icons.play_arrow;
      case VoiceEventType.stopped:
        return Icons.stop;
      case VoiceEventType.realSpeech:
        return Icons.check_circle;
      case VoiceEventType.misfire:
        return Icons.warning;
      case VoiceEventType.error:
        return Icons.error;
    }
  }

  String _getEventTitle(VoiceEventType type) {
    switch (type) {
      case VoiceEventType.started:
        return 'Speech Started';
      case VoiceEventType.stopped:
        return 'Speech Ended';
      case VoiceEventType.realSpeech:
        return 'Real Speech Confirmed';
      case VoiceEventType.misfire:
        return 'VAD Misfire';
      case VoiceEventType.error:
        return 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Activity Detection'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status indicator
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isListening
                    ? Colors.green.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isListening ? Colors.green : Colors.grey,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isListening ? Icons.mic : Icons.mic_off,
                    color: isListening ? Colors.green : Colors.grey,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    isListening
                        ? 'Listening for voice activity...'
                        : 'Not listening',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isListening ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Control buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (isListening) {
                        try {
                          await _vadHandler.stopListening();
                          setState(() {
                            isListening = false;
                            voiceEvents.clear(); // Clear events when stopping
                          });
                          debugPrint("VAD stopped successfully");
                        } catch (e) {
                          debugPrint("Error stopping VAD: $e");
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('❌ Error stopping VAD: $e')),
                          );
                        }
                      } else {
                        // Try multiple VAD configurations for better compatibility
                        debugPrint(
                            "Starting VAD with mobile-optimized settings...");
                        try {
                          // First try with more sensitive settings
                          await _vadHandler.startListening(
                            positiveSpeechThreshold: 0.3, // More sensitive
                            negativeSpeechThreshold: 0.2, // More sensitive
                            preSpeechPadFrames: 10, // Less padding for mobile
                            redemptionFrames: 8, // Shorter redemption
                            frameSamples: 512, // VAD v5 frame size
                            minSpeechFrames: 3, // Lower minimum for mobile
                            submitUserSpeechOnPause: false,
                            model: 'v5', // Use VAD v5 model
                          );
                          debugPrint(
                              "VAD startListening() completed successfully with sensitive settings");

                          setState(() {
                            isListening = true;
                            voiceEvents.clear(); // Clear events when starting

                            // Add debug event
                            voiceEvents.add(VoiceEvent(
                              type: VoiceEventType.started,
                              timestamp: DateTime.now(),
                              message:
                                  'VAD started with mobile-optimized settings (threshold: 0.3, minFrames: 3)',
                            ));
                          });

                          // Show helpful message
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '🎧 Started with sensitive settings - try speaking loudly!'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        } catch (e) {
                          debugPrint("Error starting VAD: $e");
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ Failed to start VAD: $e'),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 4),
                            ),
                          );
                          // Don't change isListening if there was an error
                        }
                      }
                    },
                    icon: Icon(isListening ? Icons.stop : Icons.mic),
                    label: Text(
                        isListening ? "Stop Listening" : "Start Listening"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isListening ? Colors.red : Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Additional test buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: !isListening
                        ? () async {
                            try {
                              debugPrint("Testing VAD v4 (legacy) model...");
                              await _vadHandler.startListening(
                                positiveSpeechThreshold: 0.2, // Very sensitive
                                negativeSpeechThreshold: 0.1, // Very sensitive
                                preSpeechPadFrames: 5, // Minimal padding
                                redemptionFrames: 4, // Short redemption
                                frameSamples: 1536, // VAD v4 frame size
                                minSpeechFrames: 2, // Very low minimum
                                submitUserSpeechOnPause: false,
                                model: 'v4', // Try legacy model
                              );

                              debugPrint(
                                  "VAD v4 startListening() completed successfully");

                              setState(() {
                                isListening = true;
                                voiceEvents.clear();
                                voiceEvents.add(VoiceEvent(
                                  type: VoiceEventType.started,
                                  timestamp: DateTime.now(),
                                  message:
                                      'VAD v4 started with ultra-sensitive settings (threshold: 0.2)',
                                ));
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '🧪 VAD v4 started with ultra-sensitive settings'),
                                  backgroundColor: Colors.purple,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            } catch (e) {
                              debugPrint("VAD v4 test failed: $e");
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('❌ VAD v4 test failed: $e')),
                              );
                            }
                          }
                        : null,
                    icon: const Icon(Icons.science),
                    label: const Text("Test v4"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    final status = await Permission.microphone.request();
                    debugPrint("Microphone permission status: $status");

                    String message;
                    SnackBarAction? action;

                    switch (status) {
                      case PermissionStatus.granted:
                        message = '🎉 Microphone permission granted!';
                        break;
                      case PermissionStatus.denied:
                        message = '❌ Microphone permission denied';
                        break;
                      case PermissionStatus.permanentlyDenied:
                        message =
                            '🔒 Permission permanently denied. Open app settings to enable.';
                        action = SnackBarAction(
                          label: 'Settings',
                          onPressed: () => openAppSettings(),
                        );
                        break;
                      case PermissionStatus.restricted:
                        message = '🚫 Microphone access is restricted';
                        break;
                      default:
                        message = '⚠️ Microphone permission: $status';
                    }

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          action: action,
                          backgroundColor: status == PermissionStatus.granted
                              ? Colors.green
                              : Colors.red[700],
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.settings_voice),
                  label: const Text("Permission"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Events list header
            if (voiceEvents.isNotEmpty)
              Text(
                'Voice Activity Log (${voiceEvents.length} events)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

            const SizedBox(height: 10),

            // Events list
            Expanded(
              child: voiceEvents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isListening ? Icons.hearing : Icons.mic_off,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isListening
                                ? 'Listening... Try speaking now!\n\nUsing VAD v5 model with optimized settings:\n• Frame size: 512 samples (32ms)\n• Min speech frames: 8 (256ms)\n• Pre-speech padding: 30 frames (960ms)'
                                : 'Press "Start Listening" to begin voice detection\n\nMake sure to grant microphone permission first!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: voiceEvents.length,
                      itemBuilder: (context, index) {
                        final event = voiceEvents[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          elevation: 2,
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: _getEventColor(event.type),
                              child: Icon(
                                _getEventIcon(event.type),
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              _getEventTitle(event.type),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
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
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  event.message,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
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
  final String message;

  VoiceEvent({
    required this.type,
    required this.timestamp,
    required this.message,
  });
}

enum VoiceEventType {
  started,
  stopped,
  realSpeech,
  misfire,
  error,
}
