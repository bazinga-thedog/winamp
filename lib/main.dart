import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

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

  String _recordedFilePath = '';

  @override
  void initState() {
    super.initState();
    _initPermissions();
    _player.openPlayer();
    _recorder.openRecorder();
  }

  Future<void> _initPermissions() async {
    await Permission.microphone.request();
    await Permission.storage.request();
  }

  Future<void> _playAssetAudio() async {
    await _audioPlayer.play(AssetSource('sample.mp3'));
  }

  Future<void> _recordVoice() async {
    Directory tempDir = await getTemporaryDirectory();
    String path = '${tempDir.path}/recorded.aac';
    setState(() {
      _recordedFilePath = path;
    });

    await _recorder.startRecorder(
      toFile: path,
      codec: Codec.aacADTS,
    );

    await Future.delayed(Duration(seconds: 5));
    await _recorder.stopRecorder();
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
          ],
        ),
      ),
    );
  }
}
