// ignore_for_file: empty_catches

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:resturant_delivery_boy/common/models/response_model.dart';
import 'package:resturant_delivery_boy/common/models/track_model.dart';
import 'package:resturant_delivery_boy/common/models/api_response_model.dart';
import 'package:resturant_delivery_boy/common/reposotories/tracker_repo.dart';
import 'package:resturant_delivery_boy/helper/api_checker_helper.dart';

class TrackerProvider extends ChangeNotifier {
  final TrackerRepo? trackerRepo;
  TrackerProvider({required this.trackerRepo});

  final List<TrackModel> _trackList = [];
  final int _selectedTrackIndex = 0;
  final bool _isBlockButton = false;
  final bool _canDismiss = true;
  bool _startTrack = false;
  Timer? _timer;

  List<TrackModel> get trackList => _trackList;
  int get selectedTrackIndex => _selectedTrackIndex;
  bool get isBlockButton => _isBlockButton;
  bool get canDismiss => _canDismiss;
  bool get startTrack => _startTrack;

  Position? _lastPosition;
  StreamSubscription<Position>? _positionStream;
  bool get isPositionStreamActive => _positionStream != null;

  // void startLocationService({bool isUpdate = true}) async {
  //
  //
  //   _startTrack = true;
  //   addTrack(isUpdate);
  //   if(_timer != null) {
  //     _timer!.cancel();
  //     _timer = null;
  //   }
  //   _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
  //     addTrack(true);
  //   });
  //
  // }

  void stopLocationService() {
    _startTrack = false;
    if(_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
    if (kDebugMode) {
      print("------------------------- Location service Stopped ----------------------- ");
    }
    notifyListeners();
  }

  // Future<ResponseModel?> addTrack(bool isUpdate) async {
  //   ResponseModel? responseModel;
  //   if (_startTrack) {
  //     Geolocator.getCurrentPosition().then((location) async {
  //       String locationText = 'demo';
  //       try {
  //         List<Placemark> placeMark = await placemarkFromCoordinates(location.latitude, location.longitude);
  //         Placemark address = placeMark.first;
  //         locationText = '${address.name ?? ''}, ${address.subAdministrativeArea ?? ''}, ${address.isoCountryCode ?? ''}';
  //       }catch(e) {}
  //       ApiResponseModel apiResponse = await trackerRepo!.addTrack(location.latitude, location.longitude, locationText);
  //       if (apiResponse.response != null && apiResponse.response!.statusCode == 200) {
  //         responseModel = ResponseModel(true, 'Successfully start track');
  //       } else {
  //         responseModel = ResponseModel(false, ApiCheckerHelper.getError(apiResponse).errors![0].message);
  //       }
  //
  //       if (kDebugMode) {
  //         print("------------------------- Location service enabled -- Lat : ${location.latitude} / Lan : ${location.longitude}");
  //       }
  //     });
  //   } else {
  //     _timer!.cancel();
  //   }
  //
  //   if(isUpdate) {
  //     notifyListeners();
  //   }
  //
  //   return responseModel;
  // }


  void startListenCurrentLocation() {
    if (_positionStream == null) {

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          distanceFilter: 10,
          accuracy: LocationAccuracy.high,
        ),
      ).listen((Position position) async {

        if (_lastPosition != null) {
          double distance = Geolocator.distanceBetween(
            _lastPosition!.latitude,
            _lastPosition!.longitude,
            position.latitude,
            position.longitude,
          );

          if (distance > 20) {

            ApiResponseModel apiResponse = await trackerRepo!.addTrack(lat: position.latitude, long: position.longitude);

            if (kDebugMode) {
              print("Location update status on sever ---- ${apiResponse.response?.statusCode}");
            }

          }
        }
        _lastPosition = position; // Update last known position
      });

      if (kDebugMode) {
        print("Location tracking started.");
      }
    }
  }

  void stopListening() {
    _positionStream?.cancel();
    _positionStream = null;
    if (kDebugMode) {
      print("Location tracking stopped.");
    }
  }


}
