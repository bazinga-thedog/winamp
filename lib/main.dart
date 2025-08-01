import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_recorder/flutter_recorder.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Recorder Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const RecorderScreen(),
    );
  }
}

class RecorderScreen extends StatefulWidget {
  const RecorderScreen({super.key});

  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isPlaying = false;
  int _recordDuration = 0;
  int _silenceDuration = 0;
  String? _recordedFilePath;
  String? _currentRecordingPath;
  Timer? _recordTimer;
  StreamSubscription? _silenceSub;
  StreamSubscription? _stateSub;

  @override
  void dispose() {
    _audioPlayer.dispose();
    _recordTimer?.cancel();
    _silenceSub?.cancel();
    _stateSub?.cancel();
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
    final filePath = '${dir.path}/flutter_recorder_${DateTime.now().millisecondsSinceEpoch}.wav';
    _currentRecordingPath = filePath;
    await Recorder.instance.init(
      sampleRate: 44100,
      channels: RecorderChannels.mono,
      format: PCMFormat.s16le,
    );
    Recorder.instance.setSilenceDetection(
      enable: true,
      onSilenceChanged: (isSilent, decibel) {
        _handleSilenceChange(isSilent, decibel);
      },
    );
    Recorder.instance.setSilenceThresholdDb(-45); // dB, adjust as needed
    Recorder.instance.setSilenceDuration(1.0); // seconds to consider as silence event
    setState(() {
      _isRecording = true;
      _recordDuration = 0;
      _silenceDuration = 0;
      _recordedFilePath = null;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordDuration++;
      });
    });
    Recorder.instance.startRecording(completeFilePath: filePath);
  }

  void _handleSilenceChange(bool isSilent, double decibel) {
    if (!_isRecording) return;
    if (isSilent) {
      // Increase silence duration
      setState(() {
        _silenceDuration++;
      });
      if (_silenceDuration >= 5) {
        _stopRecording();
      }
    } else {
      // Reset silence duration
      if (_silenceDuration != 0) {
        setState(() {
          _silenceDuration = 0;
        });
      }
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    _recordTimer?.cancel();
    _silenceSub?.cancel();
    _stateSub?.cancel();
    Recorder.instance.stopRecording();
    // Use the stored file path
    setState(() {
      _isRecording = false;
      _recordedFilePath = _currentRecordingPath;
    });
  }



  Future<void> _playRecording() async {
    if (_recordedFilePath == null) return;
    setState(() {
      _isPlaying = true;
    });
    await _audioPlayer.play(DeviceFileSource(_recordedFilePath!));
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _isPlaying = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter Recorder Demo')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isRecording) ...[
              const Icon(Icons.mic, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Recording: $_recordDuration s', style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 8),
              Text('Silence: $_silenceDuration s', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: _stopRecording,
              ),
            ] else ...[
              if (_recordedFilePath == null) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.mic),
                  label: const Text('Record'),
                  onPressed: _isPlaying ? null : _startRecording,
                ),
              ] else ...[
                ElevatedButton.icon(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text(_isPlaying ? 'Playing...' : 'Play'),
                  onPressed: _isPlaying ? null : _playRecording,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.mic),
                  label: const Text('Record Again'),
                  onPressed: _isPlaying ? null : _startRecording,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}