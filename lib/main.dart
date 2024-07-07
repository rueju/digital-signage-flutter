import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'package:wakelock/wakelock.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;

/*
VM:
IP: 10.102.201.92
Stream: digitalSignage

AWS:
IP: 13.127.84.210
Stream: mystream
*/

const server_ip = '10.102.216.142';
var playback_url = 'videos/dish.mp4';
var deploy_url= 'https://'+server_ip+'/design/deployed';

void main() {
  runApp(const VideoApp());
}

/// Stateful widget to fetch and then display video content.
class VideoApp extends StatefulWidget {
  const VideoApp({super.key});

  @override
  _VideoAppState createState() => _VideoAppState();
}

class _VideoAppState extends State<VideoApp> {
  late VideoPlayerController _controller;
  var prev_time='';
  var deployed_id = 0;
  var playing_asset = true;

  late Timer _checkTimer;

  @override
  void initState() {
    super.initState();
    setState(() {
      Wakelock.enable();
      // You could also use Wakelock.toggle(on: true);
    });


    const oneSec = Duration(seconds:5);
    _checkTimer = Timer.periodic(oneSec, (Timer t) => check_video());
    get_url();
    _controller = VideoPlayerController.asset(playback_url)
      ..initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
        setState(() {
          _controller.play();
          _controller.setLooping(true);
          playing_asset = true;
          //_controller.dispose();
        });
      });
    _controller.addListener(() {
      if(_controller.value.isBuffering){
        print('buffering');
      }else if(_controller.value.hasError){
        print('error');
      }else if(_controller.value.position == _controller.value.duration){
        print('completed');
      }
    });
  }

  Future<void> get_url() async {
    var url = Uri.parse(deploy_url);
    var id =0;
    var type= '';

    // Await the http get response, then decode the json-formatted response.
    var response = await http.get(url);
    if (response.statusCode == 200) {
      var jsonResponse =
      convert.jsonDecode(response.body) as Map<String, dynamic>;
      if (jsonResponse['result'] == 'success') {
        deployed_id = jsonResponse['id'];
         type = jsonResponse['type'];
         playback_url = 'https://$server_ip/generated/$deployed_id.mp4';
         print('streaming link: ' + playback_url);
        print('loading url '+ playback_url);
        _controller = VideoPlayerController.networkUrl(Uri.parse(playback_url))
          ..initialize().then((_) {
            // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
            setState(() {
              _controller.play();
              _controller.setLooping(true);
              //_controller.dispose();
            });
          });
        _controller.addListener(() {
          if(_controller.value.isBuffering){
            print('buffering');
          }else if(_controller.value.hasError){
            print('error');
          }else if(_controller.value.position == _controller.value.duration){
            print('completed');
          }
        });
        playing_asset = false;
      } else {
        print(jsonResponse['items'][0]);
        playback_url = 'https://$server_ip/generated/$deployed_id.mp4';
        print('streaming link: ' + playback_url);
      }
    } else {
      print('Request failed with status: ${response.statusCode}.');
    }
  }

  Future<void> check_video() async {
    late VideoPlayerController newController;
    var url = Uri.parse(deploy_url);
    // Await the http get response, then decode the json-formatted response.
    var response = await http.get(url);
    if (response.statusCode == 200) {
      var jsonResponse =
      convert.jsonDecode(response.body) as Map<String, dynamic>;
      if (jsonResponse['result'] == 'success') {
        playback_url = 'https://$server_ip/generated/$deployed_id.mp4';
        if (deployed_id == jsonResponse['id']) {
          print('src has not changed');
        }
        else {
          deployed_id = jsonResponse['id'];
          playback_url = 'https://$server_ip/generated/$deployed_id.mp4';
          print('Source changed. loading url ' + playback_url);
          newController = VideoPlayerController.networkUrl(Uri.parse(playback_url),
          )
            ..initialize().then((_) {
              setState(() {
                _controller.dispose(); // Dispose the old controller
                _controller = newController; // Assign the new controller
                _controller.play();
                _controller.setLooping(true);
              });
            });
        }
        playing_asset = false;
      } else {
        if(false == playing_asset) {
          newController = VideoPlayerController.asset('videos/dish.mp4')
            ..initialize().then((_) {
              setState(() {
                _controller.dispose(); // Dispose the old controller
                _controller = newController; // Assign the new controller
                _controller.play();
                _controller.setLooping(true);
              });
            });
        }

        playing_asset = true;
      }
    } else {
      print('Request failed with status: ${response.statusCode}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Demo',
      home: Scaffold(
        body: Center(
          child: Center(
            child: _controller.value.isInitialized
                ? AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            )
                : Container(),
          ),
        ),
      ),
    );


  }

  @override
  void dispose() {
    super.dispose();
    setState(() {
      Wakelock.disable();
      // You could also use Wakelock.toggle(on: false);
    });
    _controller.dispose();
    _checkTimer.cancel();
  }
}