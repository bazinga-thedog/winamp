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
      debugShowCheckedModeBanner: false,
    );
  }
}

class AudioPage extends StatefulWidget {
  @override
  _AudioPageState createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  final AudioPlayer player = AudioPlayer();
  final FlutterSoundRecorder recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer recordedPlayer = FlutterSoundPlayer();
  late String recordPath;
  bool isBusy = false;
  String status = 'Press the button to start';

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

    setState(() {
      isBusy = true;
      status = '🎵 Playing MP3...';
    });

    try {
      // 1. Play MP3
      await player.setAsset('assets/sample.mp3');
      await player.setVolume(1.0); // 1.0 = max volume
      await player.play();
      await player.playerStateStream.firstWhere(
        (state) => state.processingState == ProcessingState.completed,
      );

      // 2. Record for 5 seconds
      setState(() => status = '🎙️ Recording...');
      await recorder.startRecorder(
        toFile: recordPath,
        codec: Codec.aacMP4
      );
      await Future.delayed(Duration(seconds: 5));
      await recorder.stopRecorder();

      // 3. Play recorded audio
      setState(() => status = '🔊 Playing recording...');
      await recordedPlayer.setVolume(1.0);
      final duration = await recordedPlayer.startPlayer(fromURI: recordPath);
      await Future.delayed(duration ?? Duration(seconds: 5));

      setState(() {
        status = '✅ Done. Press the button to start again.';
        isBusy = false;
      });
    } catch (e) {
      print("Error: $e");
      setState(() {
        status = '❌ Error occurred.';
        isBusy = false;
      });
    }
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
      appBar: AppBar(title: Text('Audio Process Demo')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                status,
                style: TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40),
              ElevatedButton(
                onPressed: isBusy ? null : handleAudioProcess,
                child: Text(isBusy ? 'Processing...' : 'Start Process'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
