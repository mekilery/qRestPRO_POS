import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:resturant_delivery_boy/common/providers/tracker_provider.dart';
import 'package:resturant_delivery_boy/common/widgets/custom_pop_scope_widget.dart';
import 'package:resturant_delivery_boy/features/home/widgets/location_permission_widget.dart';
import 'package:resturant_delivery_boy/features/order/providers/order_provider.dart';
import 'package:resturant_delivery_boy/features/profile/providers/profile_provider.dart';
import 'package:resturant_delivery_boy/helper/location_helper.dart';
import 'package:resturant_delivery_boy/helper/notification_helper.dart';
import 'package:resturant_delivery_boy/localization/language_constrants.dart';
import 'package:resturant_delivery_boy/features/home/screens/home_screen.dart';
import 'package:resturant_delivery_boy/features/order/screens/order_history_screen.dart';
import 'package:resturant_delivery_boy/features/profile/screens/profile_screen.dart';
import 'package:resturant_delivery_boy/main.dart';
import 'package:resturant_delivery_boy/utill/dimensions.dart';
import 'package:resturant_delivery_boy/utill/styles.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();

  static late OverlayEntry overlayEntry;
  static bool isOverlayEntryAdded = false; // Add this flag
  static bool isOpenSetting = false;

  static void removeOverlayEntry() {
    if (isOverlayEntryAdded) {
      overlayEntry.remove();
      isOverlayEntryAdded = false; // Update the flag
    }
  }
}

class _DashboardScreenState extends State<DashboardScreen> {
  FlutterLocalNotificationsPlugin? flutterLocalNotificationsPlugin;
  final PageController _pageController = PageController();
  int _pageIndex = 0;
  late List<Widget> _screens;

  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();

    _screens = [
      const HomeScreen(),
      const OrderHistoryScreen(),
      const ProfileScreen(),
    ];

    _listener = AppLifecycleListener(
      onPause: () async {
        final bool isPositionStreamActive =
            Provider.of<TrackerProvider>(context, listen: false)
                .isPositionStreamActive;
        final currentLocationPermission = await Geolocator.checkPermission();
        if (isPositionStreamActive &&
            currentLocationPermission == LocationPermission.always) {
          _startForegroundLocationUpdates();
        }
      },
      onResume: () async {
        final currentLocationPermission = await Geolocator.checkPermission();

        if (currentLocationPermission == LocationPermission.denied ||
            currentLocationPermission == LocationPermission.deniedForever) {
          if (!DashboardScreen.isOverlayEntryAdded && mounted) {
            _showTopOverlay(context);
          }
        } else {
          DashboardScreen.removeOverlayEntry();

          if (currentLocationPermission != LocationPermission.always &&
              mounted) {
            _showTopOverlay(context, permission: LocationPermission.always);
          }
        }

        if (DashboardScreen.isOpenSetting) {
          DashboardScreen.isOpenSetting = false;

          _disableBatteryOptimization();
        }
        stopService();
      },
    );

    _loadData();

    _onPermissionHandel();
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPopScopeWidget(
      isExit: _pageIndex == 0,
      onPopInvoked: () {
        if (_pageIndex != 0) {
          _setPage(0);
        }
      },
      child: Scaffold(
        bottomNavigationBar: BottomNavigationBar(
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor:
              Theme.of(context).hintColor.withValues(alpha: 0.7),
          backgroundColor: Theme.of(context).cardColor,
          showUnselectedLabels: true,
          currentIndex: _pageIndex,
          type: BottomNavigationBarType.fixed,
          items: [
            _barItem(Icons.home, getTranslated('home', context), 0),
            _barItem(Icons.history, getTranslated('order_history', context), 1),
            _barItem(Icons.person, getTranslated('profile', context), 2),
          ],
          onTap: (int index) {
            _setPage(index);
          },
        ),
        body: PageView.builder(
          controller: _pageController,
          itemCount: _screens.length,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            return _screens[index];
          },
        ),
      ),
    );
  }

  BottomNavigationBarItem _barItem(IconData icon, String? label, int index) {
    return BottomNavigationBarItem(
      icon: Icon(icon,
          color: index == _pageIndex
              ? Theme.of(context).primaryColor
              : Theme.of(context).hintColor.withValues(alpha: 0.7),
          size: 20),
      label: label,
    );
  }

  void _setPage(int pageIndex) {
    setState(() {
      _pageController.jumpToPage(pageIndex);
      _pageIndex = pageIndex;
    });
  }

  Future<void> _onPermissionHandel() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final currentLocationPermission = await Geolocator.checkPermission();

      if (currentLocationPermission == LocationPermission.denied ||
          currentLocationPermission == LocationPermission.deniedForever) {
        await _checkLocationPermission();

        if (mounted) {
          _showTopOverlay(
              context); // Show overlay if permission is denied or denied forever
        }
      } else {
        DashboardScreen.removeOverlayEntry();

        if (currentLocationPermission != LocationPermission.always && mounted) {
          _showTopOverlay(context, permission: LocationPermission.always);
        }
      }
    });
  }

  void _showTopOverlay(BuildContext context,
      {LocationPermission permission = LocationPermission.denied}) {
    OverlayState? overlayState = Overlay.of(context);

    // Declare the OverlayEntry variable

    // Initialize the OverlayEntry
    DashboardScreen.overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Material(
          child: Container(
            width: MediaQuery.of(context).size.width,
            color: Theme.of(context).textTheme.bodyLarge?.color,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: Dimensions.paddingSizeSmall,
                horizontal: Dimensions.paddingSizeLarge,
              ),
              child: SafeArea(
                  top: true,
                  bottom: false,
                  child: InkWell(
                    onTap: () async {
                      if (permission == LocationPermission.always) {
                        LocationHelper.onLocationShowDialog(context,
                            dialog: LocationPermissionWidget(
                              message:
                                  '${getTranslated('always_allow_permission_message', context)} \n\n ${getTranslated('to_allow_go_to_settings', context)}',
                              onPressed: () async {
                                Navigator.pop(context);
                                DashboardScreen.isOpenSetting = true;
                                await Geolocator.openAppSettings();
                              },
                            ));
                      } else {
                        if (context.mounted) {
                          await LocationHelper.checkPermission(context);
                        }
                      }
                    },
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            permission == LocationPermission.always
                                ? Icons.gps_fixed_rounded
                                : Icons.location_on_sharp,
                            color: Colors.white,
                          ),
                          const SizedBox(width: Dimensions.paddingSizeSmall),
                          Flexible(
                              child: Text(
                            getTranslated(
                                permission == LocationPermission.always
                                    ? 'Let app run in background in order to get precise location for better performance'
                                    : 'location_sharing_disabled_top_here_to_enable',
                                context)!,
                            style: rubikRegular.copyWith(color: Colors.white),
                          )),
                          const SizedBox(width: Dimensions.paddingSizeDefault),
                          const Icon(Icons.chevron_right, color: Colors.white),
                        ]),
                  )),
            ),
          ),
        ),
      ),
    );

    // Insert the overlay into the overlay state
    overlayState.insert(DashboardScreen.overlayEntry);
    DashboardScreen.isOverlayEntryAdded = true; // Set this flag to true
  }

  Future<void> _checkLocationPermission() async {
    await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(getTranslated('why_we_need_location_access', context)!),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                getTranslated('while_in_use_permission_message', context)!,
                style: rubikRegular,
              ),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              Text(
                getTranslated('always_allow_permission_message', context)!,
                style: rubikRegular,
              ),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              Text(
                getTranslated('privacy_assurance_message', context)!,
                style: rubikRegular.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();

                _disableBatteryOptimization();
              },
              child: Text(getTranslated('cancel', context)!),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();

                await LocationHelper.checkPermission(context);
                _disableBatteryOptimization();
              },
              child: Text(getTranslated('allow', context)!),
            ),
          ],
        ),
      ),
    );
  }

  void _startForegroundLocationUpdates() async {
    FlutterForegroundTask.initCommunicationPort();

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'qRestPRO',
        channelName: 'Foreground Service Notification',
        channelDescription:
            'This notification appears when the foreground service is running.',
        onlyAlertOnce: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    // Start the foreground service
    await FlutterForegroundTask.startService(
      notificationTitle: getTranslated('location_tracking', context)!,
      notificationText:
          getTranslated('tracking_your_location_on_background', context)!,
      // callback: Provider.of<TrackerProvider>(context, listen: false).startListening,
    );
  }

  Future<void> _loadData() async {
    Provider.of<OrderProvider>(context, listen: false)
        .getCurrentOrdersList(1, context);
    Provider.of<ProfileProvider>(context, listen: false).getUserInfo(context);
    Provider.of<OrderProvider>(context, listen: false)
        .getDeliveryOrderStatistics(isUpdate: false);
    Provider.of<OrderProvider>(context, listen: false)
        .setDeliveryAnalyticsTimeRangeEnum(isReload: true, isUpdate: false);
    Provider.of<OrderProvider>(context, listen: false)
        .setSelectedSectionID(isReload: true, isUpdate: false);
    Provider.of<OrderProvider>(context, listen: false)
        .getOrderHistoryList(1, context, isUpdate: false, isReload: true);

    Provider.of<OrderProvider>(Get.context!, listen: false)
        .getOrdersCount()
        .then((orderCount) async {
      final currentLocationPermission = await Geolocator.checkPermission();

      if ((orderCount?.outForDelivery ?? 0) > 0 &&
          (currentLocationPermission != LocationPermission.denied &&
              currentLocationPermission != LocationPermission.deniedForever)) {
        Provider.of<TrackerProvider>(Get.context!, listen: false)
            .startListenCurrentLocation();
      } else if (orderCount != null &&
          orderCount.outForDelivery != null &&
          orderCount.outForDelivery! < 1) {
        Provider.of<TrackerProvider>(Get.context!, listen: false)
            .stopLocationService();
      }
    });
  }

  Future _disableBatteryOptimization() async {
    bool isDisabled =
        await DisableBatteryOptimization.isBatteryOptimizationDisabled ?? false;
    bool isAlwaysAllowLocation =
        await Geolocator.checkPermission() == LocationPermission.always;
    final NotificationSettings settings =
        await FirebaseMessaging.instance.getNotificationSettings();

    if (!isDisabled &&
        (isAlwaysAllowLocation ||
            settings.authorizationStatus == AuthorizationStatus.authorized)) {
      DisableBatteryOptimization.showDisableBatteryOptimizationSettings();
    }
  }
}
