import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';

void main() {
  runApp(AudioApp());
}

class AudioApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio Recording + Silence Detection',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: AudioHomePage(),
    );
  }
}

class AudioHomePage extends StatefulWidget {
  @override
  _AudioHomePageState createState() => _AudioHomePageState();
}

class _AudioHomePageState extends State<AudioHomePage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  String _recordedFilePath = '';
  bool _recordingActive = false;
  DateTime _lastVoiceTime = DateTime.now();
  final double _silenceThresholdDb = -45.0;
  Timer? _silenceChecker;
  double? _currentDecibel;

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    await _initPermissions();
    await _player.openPlayer();
    await _recorder.openRecorder();
  }

  Future<void> _initPermissions() async {
    await Permission.microphone.request();
    await Permission.storage.request();
  }

  Future<void> _playAssetAudio() async {
    await _audioPlayer.play(AssetSource('sample.mp3'));
  }

  Future<void> _startRecordingWithSilenceDetection() async {
    _recordingActive = true;
    Directory tempDir = await getTemporaryDirectory();
    String path = '${tempDir.path}/recorded.aac';
    _recordedFilePath = path;
    _lastVoiceTime = DateTime.now();
    _currentDecibel = null;

    await _recorder.startRecorder(
      toFile: path,
      codec: Codec.aacADTS,
      sampleRate: 44100,
      bitRate: 128000,
      numChannels: 1,
      audioSource: AudioSource.microphone,
    );

    _recorder.onProgress?.listen((event) {
      final db = event.decibels;
      if (db != null) {
        setState(() {
          _currentDecibel = db;
        });
        if (db > _silenceThresholdDb) {
          _lastVoiceTime = DateTime.now();
        }
      }
    });

    _silenceChecker?.cancel();
    _silenceChecker = Timer.periodic(Duration(milliseconds: 200), (timer) async {
      final durationSilent = DateTime.now().difference(_lastVoiceTime);
      if (_recordingActive && durationSilent.inMilliseconds > 5000) {
        timer.cancel();
        await _stopAll("Silence detected, stopping recording.");
      }
    });

    // Force stop after 20 seconds max
    Future.delayed(Duration(seconds: 20), () async {
      if (_recordingActive) {
        await _stopAll("20 seconds max recording reached.");
      }
    });
  }

  Future<void> _stopAll(String message) async {
    _recordingActive = false;
    _silenceChecker?.cancel();
    if (_recorder.isRecording) await _recorder.stopRecorder();
    await _player.closePlayer();
    await _player.openPlayer();

    Fluttertoast.showToast(msg: message, gravity: ToastGravity.BOTTOM);
    setState(() {
      _currentDecibel = null;
    });
  }

  Future<void> _playRecordedVoice() async {
    if (_recordedFilePath.isNotEmpty && File(_recordedFilePath).existsSync()) {
      await _player.startPlayer(fromURI: _recordedFilePath);
    } else {
      Fluttertoast.showToast(msg: "No recording found.", gravity: ToastGravity.BOTTOM);
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _recorder.closeRecorder();
    _player.closePlayer();
    _silenceChecker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Audio + Silence Detection'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _playAssetAudio,
              child: Text('Play Asset Audio'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _startRecordingWithSilenceDetection,
              child: Text('Record with Silence Detection'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _playRecordedVoice,
              child: Text('Play Last Recording'),
            ),
            SizedBox(height: 32),
            Text(
              _currentDecibel != null
                  ? 'Mic Level: ${_currentDecibel!.toStringAsFixed(1)} dB'
                  : 'Mic Level: -- dB',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
