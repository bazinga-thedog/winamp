import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vad/vad.dart';

void main() => runApp(AudioApp());

class AudioApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'VAD Recording',
        theme: ThemeData(primarySwatch: Colors.indigo),
        home: AudioHomePage(),
      );
}

class AudioHomePage extends StatefulWidget {
  @override
  _AudioHomePageState createState() => _AudioHomePageState();
}

class _AudioHomePageState extends State<AudioHomePage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  late final VadHandlerBase _vad;

  bool _recording = false;
  DateTime _lastVoiceTime = DateTime.now();
  Timer? _silenceChecker;
  String _recordedPath = '';

  @override
  void initState() {
    super.initState();
    _vad = VadHandler.create(isDebug: false);

    _vad.onSpeechStart.listen((_) {
      _lastVoiceTime = DateTime.now();
      _showToast("Speech started");
    });

    _vad.onRealSpeechStart.listen((_) {
      _lastVoiceTime = DateTime.now();
      _showToast("Real speech detected");
    });

    _vad.onSpeechEnd.listen((_) {
      _lastVoiceTime = DateTime.now();
      _showToast("Speech ended");
    });

    _initSetup();
  }

  Future<void> _initSetup() async {
    await Permission.microphone.request();
    await Permission.storage.request();
    await _player.openPlayer();
    await _recorder.openRecorder();
  }

  Future<void> _playAsset() async {
    await _audioPlayer.play(AssetSource('sample.mp3'));
    _showToast("Playing asset audio");
  }

  Future<void> _startRecording() async {
    _recording = true;
    Directory dir = await getTemporaryDirectory();
    _recordedPath = '${dir.path}/recorded.wav';
    _lastVoiceTime = DateTime.now();

    await _recorder.startRecorder(
      toFile: _recordedPath,
      codec: Codec.pcm16WAV,
      numChannels: 1,
      audioSource: AudioSource.microphone,
    );

    await _vad.startListening();
    _showToast("Recording started");

    _silenceChecker?.cancel();
    _silenceChecker = Timer.periodic(const Duration(milliseconds: 200), (t) async {
      if (!_recording) return t.cancel();
      if (DateTime.now().difference(_lastVoiceTime).inMilliseconds > 1000) {
        t.cancel();
        await _stopRecording("Silence detected – recording stopped");
      }
    });

    Future.delayed(const Duration(seconds: 20), () async {
      if (_recording) await _stopRecording("20‑second limit reached");
    });
  }

  Future<void> _stopRecording(String msg) async {
    _recording = false;
    _silenceChecker?.cancel();
    await _vad.stopListening();
    if (_recorder.isRecording) await _recorder.stopRecorder();
    await _player.closePlayer();
    await _player.openPlayer();
    _showToast(msg);
  }

  Future<void> _playRecording() async {
    if (_recordedPath.isNotEmpty && File(_recordedPath).existsSync()) {
      await _player.startPlayer(fromURI: _recordedPath);
      _showToast("Playing recorded audio");
    } else {
      _showToast("No recording found");
    }
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      gravity: ToastGravity.BOTTOM,
      toastLength: Toast.LENGTH_SHORT,
      fontSize: 16.0,
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _recorder.closeRecorder();
    _player.closePlayer();
    _vad.dispose();
    _silenceChecker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('VAD Recording')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(onPressed: _playAsset, child: Text('Play Asset Audio')),
              SizedBox(height: 16),
              ElevatedButton(onPressed: _startRecording, child: Text('Record with VAD')),
              SizedBox(height: 16),
              ElevatedButton(onPressed: _playRecording, child: Text('Play Recording')),
            ],
          ),
        ),
      );
}
