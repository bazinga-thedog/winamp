import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:fluttertoast/fluttertoast.dart';

void main() {
  runApp(AudioApp());
}

class AudioApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Audio App',
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
  bool _isSpeechAvailable = false;

  @override
  void initState() {
    super.initState();
    _initPermissions();
    _player.openPlayer();
    _recorder.openRecorder();
    _initSpeechRecognizer();
  }

  Future<void> _initPermissions() async {
    await Permission.microphone.request();
    await Permission.storage.request();
  }

  Future<void> _initSpeechRecognizer() async {
    _isSpeechAvailable = await _speech.initialize(
      onStatus: (status) => print('Speech status: $status'),
      onError: (error) => print('Speech error: $error'),
    );
  }

  Future<void> _playAssetAudio() async {
    await _audioPlayer.play(AssetSource('sample.mp3'));
  }

  Future<void> _recordVoice() async {
    Directory tempDir = await getTemporaryDirectory();
    String path = '${tempDir.path}/recorded.aac';
    setState(() {
      _recordedFilePath = path;
      _transcribedText = ''; // clear previous transcription
    });

    bool isSilentTimeoutTriggered = false;
    String lastTranscription = '';
    DateTime lastChangeTime = DateTime.now();

    // Start speech recognition
    if (_isSpeechAvailable) {
      await _speech.listen(
        onResult: (result) {
          final currentText = result.recognizedWords;
          if (currentText != lastTranscription) {
            setState(() {
              _transcribedText = currentText;
            });
            lastTranscription = currentText;
            lastChangeTime = DateTime.now();
          }
        },
        listenFor: Duration(seconds: 10),
        pauseFor: Duration(seconds: 1),
        localeId: 'en_US',
      );
    }

    // Start recording

    await _recorder.startRecorder(
      toFile: path,
      codec: Codec.aacADTS,
    );

    // Background watcher: check every 200ms if no new text for 1s
    Timer.periodic(Duration(milliseconds: 200), (timer) async {
      final diff = DateTime.now().difference(lastChangeTime);
      if (diff.inMilliseconds > 2000 && !isSilentTimeoutTriggered) {
        isSilentTimeoutTriggered = true;
        timer.cancel();

        // Stop recorder and speech
        await _recorder.stopRecorder();
        await _speech.stop();

        // Reset player (optional fix for volume bug)
        await _player.closePlayer();
        await _player.openPlayer();

        Fluttertoast.showToast(
          msg: "No voice detected, stopping recording.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }

      // Safety: if user talks after timeout, do nothing
      if (isSilentTimeoutTriggered) timer.cancel();
    });

    // Backup: Stop after 10 seconds max
    Future.delayed(Duration(seconds: 10), () async {
      if (!isSilentTimeoutTriggered) {
        await _recorder.stopRecorder();
        await _speech.stop();
        await _player.closePlayer();
        await _player.openPlayer();
      }
    });
    // await Future.delayed(Duration(seconds: 5));
    // await _recorder.stopRecorder();
    // // Reinitialize player to fix low-volume issue
    // await _player.closePlayer();
    // await _player.openPlayer();
    // // Stop speech recognition
    // await _speech.stop();
  }

  Future<void> _playRecordedVoice() async {
    if (_recordedFilePath.isNotEmpty && File(_recordedFilePath).existsSync()) {
      await _player.startPlayer(fromURI: _recordedFilePath);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No recording found')),
      );
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _recorder.closeRecorder();
    _player.closePlayer();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Flutter Audio Demo')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _playAssetAudio,
              child: Text('Play Asset Audio'),
            ),
            ElevatedButton(
              onPressed: _recordVoice,
              child: Text('Record Voice (5 sec)'),
            ),
            ElevatedButton(
              onPressed: _playRecordedVoice,
              child: Text('Play Recorded Voice'),
            ),
            SizedBox(height: 20),
            Text(
              'Transcribed Text:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(_transcribedText.isNotEmpty ? _transcribedText : '---'),
          ],
        ),
      ),
    );
  }
}
