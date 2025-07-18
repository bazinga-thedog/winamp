import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:fluttertoast/fluttertoast.dart';

void main() {
  runApp(AudioApp());
}

class AudioApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Audio + STT',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
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
  final stt.SpeechToText _speech = stt.SpeechToText();

  String _recordedFilePath = '';
  String _transcribedText = '';
  String _lastTranscribedText = '';
  DateTime _lastTextUpdateTime = DateTime.now();
  bool _recordingActive = false;
  bool _isSpeechAvailable = false;
  Timer? _silenceChecker;

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    await _initPermissions();
    await _player.openPlayer();
    await _recorder.openRecorder();
    _isSpeechAvailable = await _speech.initialize();
  }

  Future<void> _initPermissions() async {
    await Permission.microphone.request();
    await Permission.storage.request();
    await Permission.speech.request();
  }

  Future<void> _playAssetAudio() async {
    await _audioPlayer.play(AssetSource('sample.mp3'));
  }

  Future<void> _startRecordingWithTranscription() async {
    _transcribedText = '';
    _lastTranscribedText = '';
    _recordingActive = true;
    _lastTextUpdateTime = DateTime.now();

    Directory tempDir = await getTemporaryDirectory();
    String path = '${tempDir.path}/recorded.aac';
    _recordedFilePath = path;

    // Start recorder
    await _recorder.startRecorder(
      toFile: path,
      codec: Codec.aacADTS,
    );

    // Start STT
    if (_isSpeechAvailable) {
      await _speech.listen(
        listenFor: Duration(seconds: 10),
        pauseFor: Duration(seconds: 1),
        onResult: (result) {
          final currentText = result.recognizedWords;
          if (currentText != _lastTranscribedText) {
            _lastTranscribedText = currentText;
            _lastTextUpdateTime = DateTime.now();
            if (mounted) {
              setState(() {
                _transcribedText = currentText;
              });
            }
          }
        },
        localeId: 'en_US',
      );
    }

    // Check for silence
    _silenceChecker?.cancel();
    _silenceChecker = Timer.periodic(Duration(milliseconds: 200), (timer) async {
      final silentDuration = DateTime.now().difference(_lastTextUpdateTime);
      if (silentDuration.inMilliseconds > 1000 && _recordingActive) {
        timer.cancel();
        await _stopAll("No voice detected, stopping recording.");
      }
    });

    // Stop everything after 10 seconds max
    Future.delayed(Duration(seconds: 10), () async {
      if (_recordingActive) {
        await _stopAll("Recording stopped after 10 seconds.");
      }
    });
  }

  Future<void> _stopAll(String message) async {
    _recordingActive = false;
    _silenceChecker?.cancel();
    if (_speech.isListening) await _speech.stop();
    if (_recorder.isRecording) await _recorder.stopRecorder();
    await _player.closePlayer();
    await _player.openPlayer();

    Fluttertoast.showToast(msg: message, gravity: ToastGravity.BOTTOM);
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
    _speech.stop();
    _silenceChecker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Audio + Speech-to-Text'),
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
              onPressed: _startRecordingWithTranscription,
              child: Text('Record with STT (Auto-Stop on Silence)'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _playRecordedVoice,
              child: Text('Play Last Recording'),
            ),
            SizedBox(height: 24),
            Text(
              'Transcribed Text:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(_transcribedText.isNotEmpty ? _transcribedText : "---"),
          ],
        ),
      ),
    );
  }
}