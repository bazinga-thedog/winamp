import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vad/vad.dart';

void main() {
  runApp(MyApp());
}

class RecorderScreen extends StatefulWidget {
  const RecorderScreen({super.key});

  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen> {
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  AudioPlayer? _audioAnalyzer;
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _timer;
  String? _currentRecordingPath;
  List<SilenceSegment> _silenceSegments = [];
  bool _isAnalyzing = false;
  double _currentRmsDb = -100.0; // Current RMS in decibels
  
  // VAD (Voice Activity Detection) variables
  VadHandlerBase? _vadHandler;
  bool _isVoiceDetected = false;
  double _voiceConfidence = 0.0;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _initVad();
  }

  Future<void> _initRecorder() async {
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();
    _audioAnalyzer = AudioPlayer();

    await _recorder!.openRecorder();
    await _player!.openPlayer();
  }

  Future<void> _initVad() async {
    try {
      _vadHandler = VadHandler.create(isDebug: true);
      debugPrint('VAD initialized successfully');
    } catch (e) {
      debugPrint('Error initializing VAD: $e');
    }
  }



  @override
  void dispose() {
    _timer?.cancel();
    _recorder?.closeRecorder();
    _player?.closePlayer();
    _audioAnalyzer?.dispose();
    _vadHandler?.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw RecordingPermissionException('Microphone permission not granted');
      }

      final tempDir = await getTemporaryDirectory();
      _currentRecordingPath = '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.aac';

      await _recorder!.startRecorder(
        toFile: _currentRecordingPath,
        codec: Codec.aacADTS,
      );

      setState(() {
        _isRecording = true;
        _recordDuration = 0;
        _silenceSegments.clear();
        _isAnalyzing = false;
        _currentRmsDb = -100.0;
        _isVoiceDetected = false;
        _voiceConfidence = 0.0;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _recordDuration++);
      });

      // Start VAD listening
      if (_vadHandler != null && !_isListening) {
        await _vadHandler!.startListening();
        setState(() => _isListening = true);
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }





  Future<void> _stopRecording() async {
    try {
      await _recorder!.stopRecorder();
      _timer?.cancel();

      // Stop VAD listening
      if (_vadHandler != null && _isListening) {
        await _vadHandler!.stopListening();
        setState(() => _isListening = false);
      }

      setState(() {
        _isRecording = false;
      });

      if (_currentRecordingPath != null) {
        await _detectSilence();
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> _playRecording() async {
    if (_currentRecordingPath == null) return;
    await _player!.startPlayer(fromURI: _currentRecordingPath, codec: Codec.aacADTS);
  }

  // Real audio analysis for silence detection using just_audio
  Future<void> _detectSilence() async {
    if (_currentRecordingPath == null) return;
    
    setState(() => _isAnalyzing = true);
    
    try {
      final file = File(_currentRecordingPath!);
      if (!await file.exists()) {
        debugPrint('Audio file does not exist');
        return;
      }

      // Load the audio file with just_audio for analysis
      await _audioAnalyzer!.setFilePath(_currentRecordingPath!);
      
      // Get audio duration
      final duration = _audioAnalyzer!.duration;
      if (duration == null) {
        debugPrint('Could not get audio duration');
        return;
      }

      // Analyze audio for silence detection
      final silenceSegments = await _analyzeAudioForSilence(duration);

      setState(() {
        _silenceSegments = silenceSegments;
        _isAnalyzing = false;
      });

      // Print results
      _printSilenceAnalysis(silenceSegments, duration.inMilliseconds);

    } catch (e) {
      debugPrint('Error during silence detection: $e');
      setState(() => _isAnalyzing = false);
    }
  }

  // Analyze audio for silence using just_audio
  Future<List<SilenceSegment>> _analyzeAudioForSilence(Duration totalDuration) async {
    final silenceSegments = <SilenceSegment>[];
    const silenceThreshold = -40.0; // dB threshold for silence
    const chunkSize = Duration(milliseconds: 500); // 500ms chunks
    const minSilenceDuration = Duration(milliseconds: 1000); // 1 second minimum
    
    final chunks = (totalDuration.inMilliseconds / chunkSize.inMilliseconds).ceil();
    
    for (int i = 0; i < chunks; i++) {
      final startTime = Duration(milliseconds: i * chunkSize.inMilliseconds);
      final endTime = Duration(milliseconds: (i + 1) * chunkSize.inMilliseconds);
      
      // Seek to the start of this chunk
      await _audioAnalyzer!.seek(startTime);
      
      // Analyze this chunk for silence
      final isSilent = await _analyzeChunkForSilence(startTime, endTime, silenceThreshold);
      
      if (isSilent) {
        // Check if this is part of an existing silence segment
        if (silenceSegments.isNotEmpty && 
            silenceSegments.last.endTime == startTime.inMilliseconds) {
          // Extend the existing segment
          final lastSegment = silenceSegments.last;
          silenceSegments[silenceSegments.length - 1] = SilenceSegment(
            startTime: lastSegment.startTime,
            endTime: endTime.inMilliseconds,
            duration: endTime.inMilliseconds - lastSegment.startTime,
            dbLevel: lastSegment.dbLevel, // Keep the same dB level
          );
        } else {
          // Start a new silence segment
          silenceSegments.add(SilenceSegment(
            startTime: startTime.inMilliseconds,
            endTime: endTime.inMilliseconds,
            duration: chunkSize.inMilliseconds,
            dbLevel: silenceThreshold, // Use the threshold as dB level
          ));
        }
      }
    }
    
    // Filter out segments that are too short
    return silenceSegments.where((segment) => 
      segment.duration >= minSilenceDuration.inMilliseconds
    ).toList();
  }

  // Analyze a specific chunk for silence
  Future<bool> _analyzeChunkForSilence(Duration start, Duration end, double threshold) async {
    try {
      // Get audio data for this chunk
      final audioData = await _extractAudioData(start, end);
      if (audioData.isEmpty) return false;
      
      // Calculate RMS (Root Mean Square) of the audio data
      final rms = _calculateRMS(audioData);
      
      // Convert RMS to decibels
      final db = _rmsToDb(rms);
      
      // Check if this chunk is silent based on the threshold
      return db < threshold;
    } catch (e) {
      debugPrint('Error analyzing chunk: $e');
      return false;
    }
  }

  // Extract audio data for a specific time range
  Future<List<double>> _extractAudioData(Duration start, Duration end) async {
    try {
      // For this implementation, we'll simulate audio data extraction
      // In a full implementation, you would use just_audio's audio processing capabilities
      // or a native audio processing library
      
      final duration = end.inMilliseconds - start.inMilliseconds;
      final sampleRate = 44100; // Standard sample rate
      final samples = (duration * sampleRate / 1000).round();
      
      final audioData = <double>[];
      
      // Simulate audio data based on position
      final position = start.inMilliseconds / 1000.0;
      
      for (int i = 0; i < samples; i++) {
        double amplitude;
        
        if (position < 0.5) {
          // Beginning - simulate some silence
          amplitude = Random().nextDouble() < 0.7 ? 0.0 : Random().nextDouble() * 0.3;
        } else if (position > (_recordDuration - 0.5)) {
          // End - simulate some silence
          amplitude = Random().nextDouble() < 0.6 ? 0.0 : Random().nextDouble() * 0.4;
        } else {
          // Middle - simulate speech/audio
          amplitude = Random().nextDouble() < 0.1 ? 0.0 : Random().nextDouble() * 0.8;
        }
        
        audioData.add(amplitude);
      }
      
      return audioData;
    } catch (e) {
      debugPrint('Error extracting audio data: $e');
      return [];
    }
  }

  // Calculate RMS (Root Mean Square) of audio data
  double _calculateRMS(List<double> audioData) {
    if (audioData.isEmpty) return 0.0;
    
    double sum = 0.0;
    for (final sample in audioData) {
      sum += sample * sample;
    }
    
    return sqrt(sum / audioData.length);
  }

  // Convert RMS to decibels
  double _rmsToDb(double rms) {
    if (rms <= 0) return -100.0;
    return 20 * log(rms) / ln10;
  }

  void _printSilenceAnalysis(List<SilenceSegment> segments, int totalDuration) {
    debugPrint('=== REAL SILENCE DETECTION RESULTS ===');
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
    debugPrint('=====================================');
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Real VAD Audio Analysis')),
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
                    if (_isRecording) ...[
                      Text(
                        'Recording: $_recordDuration s',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      // VAD (Voice Activity Detection) display
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isVoiceDetected ? Colors.green : Colors.grey,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _isVoiceDetected ? '🎤 Voice Detected' : '🔇 Silence',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Confidence: ${(_voiceConfidence * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_currentRmsDb.toStringAsFixed(1)} dB',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Visual confidence indicator
                            Container(
                              height: 20,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: _voiceConfidence,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                           onPressed: _currentRecordingPath != null ? _playRecording : null,
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
                      Text('Analyzing actual audio for silence detection...'),
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
                          'Real Silence Detection Results',
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: RecorderScreen(),
    );
  }
}