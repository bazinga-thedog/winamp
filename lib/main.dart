import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:noise_meter/noise_meter.dart';

void main() {
  runApp(AudioApp());
}

class AudioApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Noise Meter Recording',
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
  final NoiseMeter _noiseMeter = NoiseMeter();

  StreamSubscription<NoiseReading>? _noiseSubscription;
  double? _currentDecibel;
  DateTime _lastVoiceTime = DateTime.now();
  final double _silenceThresholdDb = 50.0; // Plugin: meanDecibel over 50 = voice
  bool _recordingActive = false;
  Timer? _silenceChecker;
  String _recordedFilePath = '';

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    await Permission.microphone.request();
    await Permission.storage.request();
    await _player.openPlayer();
    await _recorder.openRecorder();
  }

  Future<void> _playAssetAudio() async {
    await _audioPlayer.play(AssetSource('sample.mp3'));
  }

  Future<void> _startRecordingWithNoiseDetection() async {
    _recordingActive = true;
    Directory dir = await getTemporaryDirectory();
    _recordedFilePath = '${dir.path}/recorded.wav';
    _lastVoiceTime = DateTime.now();
    _currentDecibel = null;

    await _recorder.startRecorder(
      toFile: _recordedFilePath,
      codec: Codec.pcm16WAV,
      sampleRate: 44100,
      bitRate: 128000,
      numChannels: 1,
      audioSource: AudioSource.microphone,
    );

    _noiseSubscription = _noiseMeter.noise.listen((NoiseReading reading) {
      setState(() {
        _currentDecibel = reading.meanDecibel;
      });
      if (reading.meanDecibel > _silenceThresholdDb) {
        _lastVoiceTime = DateTime.now();
      }
    }, onError: (err) {
      print('NoiseMeter error: $err');
    });

    _silenceChecker?.cancel();
    _silenceChecker = Timer.periodic(Duration(milliseconds: 200), (timer) async {
      if (!_recordingActive) return timer.cancel();
      if (DateTime.now().difference(_lastVoiceTime).inMilliseconds > 1000) {
        timer.cancel();
        await _stopAll("Silence detected—stopping recording.");
      }
    });

    Future.delayed(Duration(seconds: 20), () async {
      if (_recordingActive) {
        await _stopAll("20s max recording reached.");
      }
    });
  }

  Future<void> _stopAll(String msg) async {
    _recordingActive = false;
    _silenceChecker?.cancel();
    await _noiseSubscription?.cancel();
    if (_recorder.isRecording) await _recorder.stopRecorder();
    await _player.closePlayer();
    await _player.openPlayer();

    Fluttertoast.showToast(msg: msg, gravity: ToastGravity.BOTTOM);
    setState(() => _currentDecibel = null);
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
    _noiseSubscription?.cancel();
    _silenceChecker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Noise Meter Recording')),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(onPressed: _playAssetAudio, child: Text('Play Asset Audio')),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _startRecordingWithNoiseDetection,
              child: Text('Record with Noise Detection'),
            ),
            SizedBox(height: 16),
            ElevatedButton(onPressed: _playRecordedVoice, child: Text('Play Recording')),
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
