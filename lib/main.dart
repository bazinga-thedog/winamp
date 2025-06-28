import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart'; // New audio player
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local Audio Player',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const AudioPlayerScreen(),
    );
  }
}

class AudioPlayerScreen extends StatefulWidget {
  const AudioPlayerScreen({super.key});

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer(); // Create an instance of AudioPlayer
  PlayerState _playerState = PlayerState.stopped; // To track current player state
  String? _currentAudioPath; // To store the path of the currently playing audio
  bool _isPicking = false; // To prevent multiple file pickers opening

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    // Listen to player state changes
    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _playerState = state;
      });
    });
    // Listen to completion of audio
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _playerState = PlayerState.completed;
      });
    });
  }

  Future<void> _requestPermissions() async {
    // Request storage permissions
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }

    // For Android 13+ (API 33+), request specific media audio permission
    if (Platform.isAndroid && await Permission.audio.status != PermissionStatus.granted) {
      await Permission.audio.request();
    }

    if (status.isGranted) {
      print('Storage permission granted');
    } else {
      print('Storage permission denied');
      // Optionally show a dialog to the user explaining why permission is needed
    }
  }

  Future<void> _pickAndPlayAudio() async {
    if (_isPicking) return; // Prevent multiple pickers

    setState(() {
      _isPicking = true;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio, // Changed to audio type
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        _currentAudioPath = result.files.single.path!;
        await _playAudio(_currentAudioPath!);
      } else {
        // User canceled the picker
        print('Audio picking cancelled');
      }
    } catch (e) {
      print('Error picking audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking audio: $e')),
      );
    } finally {
      setState(() {
        _isPicking = false;
      });
    }
  }

  Future<void> _playAudio(String filePath) async {
    // Stop any currently playing audio before playing a new one
    await _audioPlayer.stop();
    await _audioPlayer.play(DeviceFileSource(filePath));
    setState(() {
      _playerState = PlayerState.playing;
    });
  }

  // Toggles play/pause
  Future<void> _togglePlayPause() async {
    if (_playerState == PlayerState.playing) {
      await _audioPlayer.pause();
    } else if (_playerState == PlayerState.paused || _playerState == PlayerState.completed || _playerState == PlayerState.stopped) {
      // If paused, completed, or stopped, play from current position or start
      await _audioPlayer.resume(); // Use resume to continue from where it left off
    }
    setState(() {}); // Update UI based on new state
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // Release resources when the widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Play Local MP3/Audio'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              _currentAudioPath != null
                  ? 'Currently playing: ${Uri.file(_currentAudioPath!).pathSegments.last}'
                  : 'No audio selected',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isPicking ? null : _pickAndPlayAudio,
                  child: const Text('Pick and Play Audio'),
                ),
                if (_currentAudioPath != null) // Only show play/pause if an audio is selected
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: FloatingActionButton(
                      onPressed: _togglePlayPause,
                      child: Icon(
                        _playerState == PlayerState.playing ? Icons.pause : Icons.play_arrow,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Player State: ${_playerState.name}'),
          ],
        ),
      ),
    );
  }
}