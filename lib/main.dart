import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(AudioApp());
}

class AudioApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio Recorder Demo',
      home: AudioPage(),
    );
  }
}

class AudioPage extends StatefulWidget {
  @override
  _AudioPageState createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  final player = AudioPlayer();
  final recorder = FlutterSoundRecorder();
  final recordedPlayer = FlutterSoundPlayer();
  late String recordPath;
  bool isBusy = false;

  @override
  void initState() {
    super.initState();
    initRecorder();
  }

  Future<void> initRecorder() async {
    await Permission.microphone.request();
    await Permission.storage.request();
    await recorder.openRecorder();
    await recordedPlayer.openPlayer();
    Directory tempDir = await getTemporaryDirectory();
    recordPath = '${tempDir.path}/recorded.aac';
  }

  Future<void> handleAudioProcess() async {
    if (isBusy) return;
    setState(() => isBusy = true);

    try {
      // 1. Play MP3 file from assets
      await player.setAsset('assets/sample.mp3');
      await player.play();
      await player.playerStateStream.firstWhere((state) => state.processingState == ProcessingState.completed);

      // 2. Record for 5 seconds
      await recorder.startRecorder(toFile: recordPath, codec: Codec.aacMP4);
      await Future.delayed(Duration(seconds: 5));
      await recorder.stopRecorder();

      // 3. Play the recorded audio
      final duration = await recordedPlayer.startPlayer(
        fromURI: recordPath,
      );
      await Future.delayed(duration ?? Duration(seconds: 5));

    } catch (e) {
      print("Error: $e");
    }

    setState(() => isBusy = false);
  }

  @override
  void dispose() {
    player.dispose();
    recorder.closeRecorder();
    recordedPlayer.closePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Audio Player & Recorder')),
      body: Center(
        child: ElevatedButton(
          onPressed: isBusy ? null : handleAudioProcess,
          child: Text(isBusy ? 'Processing...' : 'Start Process'),
        ),
      ),
    );
  }
}
