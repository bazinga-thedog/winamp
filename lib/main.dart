import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio Player Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AudioPlayerScreen(),
    );
  }
}

class AudioPlayerScreen extends StatefulWidget {
  @override
  _AudioPlayerScreenState createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isPlaying = false;
  bool _isRecording = false;
  bool _hasRecording = false;
  String _recordingPath = '';
  String _status = 'Ready to start';
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    
    // Listen to player state changes
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
        if (!_isPlaying && !_isRecording && !_hasRecording) {
          _status = 'Ready to start';
        }
      });
    });
    
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    if (await Permission.microphone.isDenied) {
      await Permission.microphone.request();
    }
  }

  Future<void> _startConversationFlow() async {
    setState(() {
      _hasRecording = false;
      _status = 'Playing question...';
    });
    
    // Step 1: Play the question
    await _playAudio();
    
    // Wait for audio to finish playing
    await Future.delayed(Duration(milliseconds: 500));
    
    // Step 2: Start recording for 3 seconds
    await _startRecording();
  }

  Future<void> _playAudio() async {
    try {
      await _audioPlayer.play(AssetSource('audio/question.mp3'));
    } catch (e) {
      print('Error playing audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing audio: $e')),
      );
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await Permission.microphone.isGranted) {
        // Get app documents directory
        final directory = await Directory.systemTemp.createTemp();
        _recordingPath = '${directory.path}/recording.m4a';
        
        setState(() {
          _isRecording = true;
          _status = 'Recording... (3 seconds)';
        });
        
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: _recordingPath,
        );
        
        // Record for 3 seconds
        _recordingTimer = Timer(Duration(seconds: 3), () {
          _stopRecording();
        });
        
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Microphone permission required')),
        );
      }
    } catch (e) {
      print('Error starting recording: $e');
      setState(() {
        _isRecording = false;
        _status = 'Error starting recording';
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder.stop();
      _recordingTimer?.cancel();
      
      setState(() {
        _isRecording = false;
        _hasRecording = true;
        _status = 'Recording complete. Click to play back.';
      });
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  Future<void> _playRecording() async {
    if (_hasRecording && _recordingPath.isNotEmpty) {
      try {
        setState(() {
          _status = 'Playing your recording...';
        });
        await _audioPlayer.play(DeviceFileSource(_recordingPath));
      } catch (e) {
        print('Error playing recording: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing recording: $e')),
        );
      }
    }
  }

  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
  }

  void _reset() {
    setState(() {
      _hasRecording = false;
      _isRecording = false;
      _status = 'Ready to start';
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Conversational Flow Demo'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isRecording ? Icons.mic : (_isPlaying ? Icons.volume_up : Icons.volume_off),
              size: 80,
              color: _isRecording ? Colors.red : (_isPlaying ? Colors.blue : Colors.grey),
            ),
            SizedBox(height: 30),
            
            // Main action button
            ElevatedButton(
              onPressed: _isRecording ? null : (_hasRecording ? _playRecording : _startConversationFlow),
              child: Text(_hasRecording ? 'Play Recording' : 'Start Conversation'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: TextStyle(fontSize: 18),
              ),
            ),
            
            SizedBox(height: 20),
            
            // Reset button
            if (_hasRecording)
              ElevatedButton(
                onPressed: _reset,
                child: Text('Reset'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            
            SizedBox(height: 20),
            
            // Status text
            Text(
              _status,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}