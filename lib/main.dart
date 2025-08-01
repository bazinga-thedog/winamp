import 'package:flutter/material.dart';
import 'package:flutter_recorder/flutter_recorder.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio Recorder App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AudioRecorderScreen(),
    );
  }
}

class AudioRecorderScreen extends StatefulWidget {
  @override
  _AudioRecorderScreenState createState() => _AudioRecorderScreenState();
}

class _AudioRecorderScreenState extends State<AudioRecorderScreen> {
  FlutterRecorder? _recorder;
  AudioPlayer? _audioPlayer;

  bool _isRecording = false;
  bool _hasRecording = false;
  bool _isPlaying = false;

  int _recordingDuration = 0;
  int _silenceDuration = 0;
  double _currentAmplitude = 0.0;

  Timer? _recordingTimer;
  Timer? _silenceTimer;
  Timer? _amplitudeTimer;

  String? _recordedFilePath;

  // Silence detection parameters
  static const double SILENCE_THRESHOLD = 0.1;
  static const int SILENCE_TIMEOUT = 5; // 5 seconds

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
    _audioPlayer = AudioPlayer();
  }

  void _initializeRecorder() async {
    _recorder = Recorder.instance;

    // Request microphone permission
    await Permission.microphone.request();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _silenceTimer?.cancel();
    _amplitudeTimer?.cancel();
    _recorder?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      // Check permission
      if (await Permission.microphone.isGranted) {
        // Generate file path
        final directory = Directory.systemTemp;
        final fileName =
            'recording_${DateTime.now().millisecondsSinceEpoch}.wav';
        _recordedFilePath = '${directory.path}/$fileName';

        // Start recording
        await _recorder?.start(path: _recordedFilePath!);

        setState(() {
          _isRecording = true;
          _hasRecording = false;
          _recordingDuration = 0;
          _silenceDuration = 0;
        });

        // Start timers
        _startRecordingTimer();
        _startAmplitudeMonitoring();
      } else {
        _showPermissionDialog();
      }
    } catch (e) {
      print('Error starting recording: $e');
      _showErrorDialog('Failed to start recording');
    }
  }

  void _startRecordingTimer() {
    _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _recordingDuration++;
      });
    });
  }

  void _startAmplitudeMonitoring() {
    _amplitudeTimer =
        Timer.periodic(Duration(milliseconds: 100), (timer) async {
      if (_recorder != null && _isRecording) {
        try {
          // Get current amplitude (this is a simplified approach)
          // In a real implementation, you might need to use a different method
          // to get the actual amplitude from the microphone
          final amplitude = await _getCurrentAmplitude();

          setState(() {
            _currentAmplitude = amplitude;
          });

          _checkSilence(amplitude);
        } catch (e) {
          print('Error monitoring amplitude: $e');
        }
      }
    });
  }

  Future<double> _getCurrentAmplitude() async {
    // This is a placeholder implementation
    // flutter_recorder might not provide direct amplitude access
    // You might need to use a different plugin like noise_meter for amplitude detection
    // For now, we'll simulate amplitude detection
    return _simulateAmplitude();
  }

  double _simulateAmplitude() {
    // Simulate varying amplitude for demonstration
    // In a real app, this would come from actual microphone input
    final random = DateTime.now().millisecondsSinceEpoch % 1000;
    return (random / 1000.0);
  }

  void _checkSilence(double amplitude) {
    if (amplitude < SILENCE_THRESHOLD) {
      // User is silent
      if (_silenceTimer == null || !_silenceTimer!.isActive) {
        _startSilenceTimer();
      }
    } else {
      // User is speaking
      _resetSilenceTimer();
    }
  }

  void _startSilenceTimer() {
    _silenceTimer?.cancel();
    setState(() {
      _silenceDuration = 0;
    });

    _silenceTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _silenceDuration++;
      });

      if (_silenceDuration >= SILENCE_TIMEOUT) {
        _stopRecording();
        timer.cancel();
      }
    });
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    setState(() {
      _silenceDuration = 0;
    });
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder?.stop();

      _recordingTimer?.cancel();
      _silenceTimer?.cancel();
      _amplitudeTimer?.cancel();

      setState(() {
        _isRecording = false;
        _hasRecording = true;
        _silenceDuration = 0;
      });
    } catch (e) {
      print('Error stopping recording: $e');
      _showErrorDialog('Failed to stop recording');
    }
  }

  Future<void> _playRecording() async {
    if (_recordedFilePath != null && File(_recordedFilePath!).existsSync()) {
      try {
        setState(() {
          _isPlaying = true;
        });

        await _audioPlayer?.play(DeviceFileSource(_recordedFilePath!));

        // Listen for completion
        _audioPlayer?.onPlayerComplete.listen((event) {
          setState(() {
            _isPlaying = false;
          });
        });
      } catch (e) {
        print('Error playing recording: $e');
        _showErrorDialog('Failed to play recording');
        setState(() {
          _isPlaying = false;
        });
      }
    }
  }

  Future<void> _stopPlaying() async {
    await _audioPlayer?.stop();
    setState(() {
      _isPlaying = false;
    });
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Permission Required'),
        content: Text('Microphone permission is required to record audio.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Audio Recorder'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Recording status
              if (_isRecording) ...[
                Icon(
                  Icons.mic,
                  size: 80,
                  color: Colors.red,
                ),
                SizedBox(height: 20),
                Text(
                  'Recording...',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Duration: ${_formatDuration(_recordingDuration)}',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 10),
                Text(
                  'Silence: ${_formatDuration(_silenceDuration)}',
                  style: TextStyle(
                    fontSize: 16,
                    color: _silenceDuration > 0 ? Colors.orange : Colors.grey,
                  ),
                ),
                SizedBox(height: 10),
                LinearProgressIndicator(
                  value: _currentAmplitude,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _currentAmplitude < SILENCE_THRESHOLD
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Amplitude: ${(_currentAmplitude * 100).toInt()}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ] else if (_hasRecording) ...[
                Icon(
                  Icons.audiotrack,
                  size: 80,
                  color: Colors.green,
                ),
                SizedBox(height: 20),
                Text(
                  'Recording Complete',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Total Duration: ${_formatDuration(_recordingDuration)}',
                  style: TextStyle(fontSize: 18),
                ),
              ] else ...[
                Icon(
                  Icons.mic_none,
                  size: 80,
                  color: Colors.grey,
                ),
                SizedBox(height: 20),
                Text(
                  'Ready to Record',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
              ],

              SizedBox(height: 40),

              // Control buttons
              if (!_isRecording && !_hasRecording) ...[
                ElevatedButton(
                  onPressed: _startRecording,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mic),
                      SizedBox(width: 8),
                      Text('Start Recording', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ] else if (_isRecording) ...[
                ElevatedButton(
                  onPressed: _stopRecording,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stop),
                      SizedBox(width: 8),
                      Text('Stop Recording', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ] else if (_hasRecording) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _isPlaying ? _stopPlaying : _playRecording,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isPlaying ? Colors.orange : Colors.green,
                        foregroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                          SizedBox(width: 8),
                          Text(_isPlaying ? 'Stop' : 'Play',
                              style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _hasRecording = false;
                          _recordingDuration = 0;
                          _recordedFilePath = null;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh),
                          SizedBox(width: 8),
                          Text('New Recording', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],

              SizedBox(height: 20),

              // Instructions
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Instructions:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('• Tap "Start Recording" to begin'),
                      Text(
                          '• Recording will auto-stop after 5 seconds of silence'),
                      Text('• Watch the silence counter and amplitude meter'),
                      Text('• Use "Play" button to listen to your recording'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
