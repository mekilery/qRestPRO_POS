import 'package:flutter/material.dart';
import 'package:resturant_delivery_boy/common/widgets/custom_asset_image_widget.dart';
import 'package:resturant_delivery_boy/localization/language_constrants.dart';
import 'package:resturant_delivery_boy/utill/dimensions.dart';
import 'package:resturant_delivery_boy/utill/images.dart';
import 'package:resturant_delivery_boy/utill/styles.dart';

class LocationPermissionWidget extends StatelessWidget {
  final Function onPressed;
  final String? message;
  const LocationPermissionWidget({Key? key, required this.onPressed, this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      // title: Text(getTranslated('alert', context)!),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CustomAssetImageWidget(Images.locationPermission, width: 100, height: 100),
          const SizedBox(height: Dimensions.paddingSizeDefault),

          Text(message ??  getTranslated('please_allow_location_access', context)!),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusSmall)),
      actions: [InkWell(
        onTap: onPressed as void Function()?,
        child: Text(getTranslated('go_to_setting', context)!, style: rubikMedium.copyWith(color: Theme.of(context).primaryColor),),
      )],
    );
  }
}
