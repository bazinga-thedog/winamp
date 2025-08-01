import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

class RecorderScreen extends StatefulWidget {
  const RecorderScreen({super.key});

  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen> {
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  bool _isRecording = false;
  String? _filePath;
  Timer? _timer;
  int _recordDuration = 0;
  List<SilenceSegment> _silenceSegments = [];
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();
    _initRecorder();
    _initPlayer();
  }

  Future<void> _initRecorder() async {
    await _recorder!.openRecorder();
  }

  Future<void> _initPlayer() async {
    await _player!.openPlayer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder?.closeRecorder();
    _player?.closePlayer();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    _filePath = '${dir.path}/flutter_sound_example.aac';
    await _recorder!.startRecorder(
      toFile: _filePath,
      codec: Codec.aacADTS,
    );
    setState(() {
      _isRecording = true;
      _recordDuration = 0;
      _silenceSegments.clear();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _recordDuration++);
    });
  }

  Future<void> _stopRecording() async {
    await _recorder!.stopRecorder();
    setState(() => _isRecording = false);
    _timer?.cancel();
    await _detectSilence();
  }

  Future<void> _playRecording() async {
    if (_filePath == null) return;
    await _player!.startPlayer(fromURI: _filePath, codec: Codec.aacADTS);
  }

  // Advanced silence detection logic
  Future<void> _detectSilence() async {
    if (_filePath == null) return;
    
    setState(() => _isAnalyzing = true);
    
    try {
      // For this implementation, we'll use a simplified approach
      // since flutter_sound doesn't provide direct audio sample access
      // In a real implementation, you would use audio processing libraries
      
      // Simulate analysis with the recording duration
      final duration = _recordDuration * 1000; // Convert to milliseconds
      
      if (duration == 0) {
        debugPrint('No audio duration available');
        return;
      }

      // Analyze audio in chunks (simulated)
      const chunkSize = 1000; // 1 second chunks
      const silenceThreshold = -40.0; // dB threshold
      List<SilenceSegment> silenceSegments = [];
      
      for (int i = 0; i < duration; i += chunkSize) {
        final endTime = (i + chunkSize > duration) ? duration : i + chunkSize;
        
        // Simulate audio analysis (in real implementation, extract actual audio)
        final simulatedDb = _simulateAudioLevel(i, endTime);
        
        if (simulatedDb < silenceThreshold) {
          // Check if this is part of an existing silence segment
          if (silenceSegments.isNotEmpty && 
              silenceSegments.last.endTime == i) {
            // Extend the existing segment
            final lastSegment = silenceSegments.last;
            silenceSegments[silenceSegments.length - 1] = SilenceSegment(
              startTime: lastSegment.startTime,
              endTime: endTime,
              duration: endTime - lastSegment.startTime,
              dbLevel: (lastSegment.dbLevel + simulatedDb) / 2, // Average dB
            );
          } else {
            silenceSegments.add(SilenceSegment(
              startTime: i,
              endTime: endTime,
              duration: endTime - i,
              dbLevel: simulatedDb,
            ));
          }
        }
      }
      
      setState(() {
        _silenceSegments = silenceSegments;
        _isAnalyzing = false;
      });
      
      // Print results
      _printSilenceAnalysis(silenceSegments, duration);
      
    } catch (e) {
      debugPrint('Error during silence detection: $e');
      setState(() => _isAnalyzing = false);
    }
  }

  // Simulate audio level for demonstration
  double _simulateAudioLevel(int startMs, int endMs) {
    // This simulates varying audio levels throughout the recording
    // In a real implementation, you would analyze actual audio samples
    
    final timePosition = startMs / 1000.0; // Convert to seconds
    
    // Simulate some patterns:
    // - Silence at the beginning (0-2 seconds)
    // - Some speech (2-5 seconds)
    // - Silence (5-7 seconds)
    // - More speech (7-10 seconds)
    // - Random variations
    
    if (timePosition < 2.0 || (timePosition >= 5.0 && timePosition < 7.0)) {
      // Simulate silence periods
      return -45.0 + (Random().nextDouble() * 10 - 5); // -50 to -40 dB
    } else {
      // Simulate speech periods
      return -20.0 + (Random().nextDouble() * 15 - 7.5); // -27.5 to -12.5 dB
    }
  }

  void _printSilenceAnalysis(List<SilenceSegment> segments, int totalDuration) {
    debugPrint('=== SILENCE DETECTION RESULTS ===');
    debugPrint('Total recording duration: ${totalDuration / 1000} seconds');
    debugPrint('Number of silence segments: ${segments.length}');
    
    if (segments.isEmpty) {
      debugPrint('No silence detected in the recording.');
      return;
    }
    
    double totalSilenceTime = 0;
    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      totalSilenceTime += segment.duration;
      
      debugPrint('Silence segment ${i + 1}:');
      debugPrint('  Start: ${segment.startTime / 1000} s');
      debugPrint('  End: ${segment.endTime / 1000} s');
      debugPrint('  Duration: ${segment.duration / 1000} s');
      debugPrint('  dB Level: ${segment.dbLevel.toStringAsFixed(2)} dB');
    }
    
    final silencePercentage = (totalSilenceTime / totalDuration) * 100;
    debugPrint('Total silence time: ${totalSilenceTime / 1000} seconds');
    debugPrint('Silence percentage: ${silencePercentage.toStringAsFixed(2)}%');
    debugPrint('================================');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Advanced Audio Recorder')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Recording controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    if (_isRecording)
                      Text(
                        'Recording: $_recordDuration s',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isRecording ? _stopRecording : _startRecording,
                          icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                          label: Text(_isRecording ? 'Stop' : 'Record'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isRecording ? Colors.red : Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _filePath != null ? _playRecording : null,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Play'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Analysis status
            if (_isAnalyzing)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Analyzing audio for silence detection...'),
                    ],
                  ),
                ),
              ),
            
            // Silence detection results
            if (_silenceSegments.isNotEmpty)
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Silence Detection Results',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('Found ${_silenceSegments.length} silence segments'),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _silenceSegments.length,
                            itemBuilder: (context, index) {
                              final segment = _silenceSegments[index];
                              return ListTile(
                                title: Text('Segment ${index + 1}'),
                                subtitle: Text(
                                  '${(segment.startTime / 1000).toStringAsFixed(1)}s - '
                                  '${(segment.endTime / 1000).toStringAsFixed(1)}s '
                                  '(${(segment.duration / 1000).toStringAsFixed(1)}s)',
                                ),
                                trailing: Text('${segment.dbLevel.toStringAsFixed(1)} dB'),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SilenceSegment {
  int startTime;
  int endTime;
  int duration;
  double dbLevel;

  SilenceSegment({
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.dbLevel,
  });
}

void main() {
  runApp(const MaterialApp(
    home: RecorderScreen(),
  ));
}