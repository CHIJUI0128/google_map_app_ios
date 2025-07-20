// 完整 Flutter OCR + Google Map + 即時定位 + 標記導航頁面

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class OcrMapPage extends StatefulWidget {
  @override
  _OcrMapPageState createState() => _OcrMapPageState();
}

class _OcrMapPageState extends State<OcrMapPage> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  File? _imageFile;
  String? _name;
  String? _address;

  final String ocrApiUrl = 'http://192.168.0.17:5000/ocr';
  final String sheetPostUrl = 'https://script.google.com/macros/s/AKfycbzd9Fmk1vgFj0dcuh70HC5oi8kPxNVo3RO4n6Y2O2pagD9gBCtCNHTUU9FHhLxsH-xS/exec';
  final String sheetJsonUrl = 'https://opensheet.elk.sh/1oS_XPHSBBTsWyfdOTj6j_8w_vM_AZumFbzTHLo9Fnqk/Sheet1';
  Future<void> _pickAndSendImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('尚未選擇圖片')),
        );
        return;
      }

      setState(() {
        _imageFile = File(pickedFile.path);
        _name = null;
        _address = null;
      });

      // 傳送圖片到 OCR API
      var request = http.MultipartRequest('POST', Uri.parse(ocrApiUrl));
      request.files.add(await http.MultipartFile.fromPath('image', pickedFile.path));
      var response = await request.send();

      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var data = json.decode(responseData);
        setState(() {
          _name = data['name'];
          _address = data['address'];
        });

        // 上傳到 Google Sheet
        final sheetRes = await http.get(Uri.parse('$sheetPostUrl?name=$_name&address=$_address'));
        print('✅ Sheet 回傳: ${sheetRes.statusCode} ${sheetRes.body}');

        // 重新載入地圖標記
        await Future.delayed(Duration(seconds: 2));
        _loadMarkers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('辨識失敗：${response.statusCode}')),
        );
      }
    } catch (e) {
      print('❌ 發生錯誤: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('發生錯誤：$e')),
      );
    }
  }

  Future<void> _loadMarkers() async {
    try {
      final response = await http.get(Uri.parse(sheetJsonUrl));
      debugPrint("📄 Raw JSON: ${utf8.decode(response.bodyBytes)}");

      final List data = json.decode(utf8.decode(response.bodyBytes));
      Set<Marker> markers = {};

      for (var item in data) {
        final name = item['name'];
        final address = item['address'];
        final time = item['time'] ?? ''; // ✅ 加入時間欄位

        if (name != null && address != null && address.toString().isNotEmpty) {
          try {
            List<Location> locations = await locationFromAddress(address);
            if (locations.isNotEmpty) {
              final loc = locations.first;
              markers.add(Marker(
                markerId: MarkerId(name),
                position: LatLng(loc.latitude, loc.longitude),
                infoWindow: InfoWindow(
                  title: name,
                  snippet: '$address\n🕒 $time', // ✅ 顯示時間
                  onTap: () => _openGoogleMapsNavigation(loc.latitude, loc.longitude),
                ),
              ));
            } else {
              debugPrint('⚠️ Geocoding 找不到: $address');
            }
          } catch (e) {
            debugPrint('❌ Geocoding 失敗: $address, error=${e.toString()}');
          }
        }
      }

      if (markers.isEmpty) {
        markers.add(Marker(
          markerId: MarkerId('debug'),
          position: LatLng(25.034, 121.5645),
          infoWindow: InfoWindow(title: 'Debug Marker'),
        ));
      }

      setState(() {
        _markers = markers;
      });

      debugPrint('✅ Marker 數量: ${_markers.length}');
    } catch (e) {
      debugPrint('❌ 無法載入地標: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('載入地標失敗：${e.toString()}')),
      );
    }
  }

  Future<void> _moveToCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) return;

    Position position = await Geolocator.getCurrentPosition();

    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
      LatLng(position.latitude, position.longitude),
      16,
    ));
  }

  void _openGoogleMapsNavigation(double lat, double lng) async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('無法打開 Google Maps')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMarkers();
    _moveToCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("OCR + 地圖 Demo")),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(25.0330, 121.5654),
              zoom: 12,
            ),
            markers: _markers,
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              icon: Icon(Icons.photo),
              label: Text("選擇圖片並辨識"),
              onPressed: _pickAndSendImage,
            ),
          ),
        ],
      ),
    );
  }
}
