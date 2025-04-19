<?php

namespace App\CentralLogics;

use App\Model\BusinessSetting;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\DB;
use Twilio\Rest\Client;

class SMS_module
{
    public static function send($receiver, $otp)
    {
        $config = self::get_settings('twilio');
        // Check Twilio first as it's the target for modification
        if (isset($config) && $config['status'] == 1) {
            // Attempt sending via Twilio (potentially WhatsApp)
            $response = self::twilio($receiver, $otp);
            if ($response == 'success') {
                return $response;
            }
            // If Twilio fails or isn't configured for WhatsApp, maybe fallback or just return error?
            // For now, let's proceed with original fallback logic if twilio fails.
        }


        $config = self::get_settings('nexmo');
        if (isset($config) && $config['status'] == 1) {
            return self::nexmo($receiver, $otp);
        }

        $config = self::get_settings('2factor');
        if (isset($config) && $config['status'] == 1) {
            return self::two_factor($receiver, $otp);
        }

        $config = self::get_settings('msg91');
        if (isset($config) && $config['status'] == 1) {
            return self::msg_91($receiver, $otp);
        }

         $config = self::get_settings('signal_wire');
         if (isset($config) && $config['status'] == 1) {
             return self::signal_wire($receiver, $otp);
         }

        $config = self::get_settings('alphanet_sms');
        if (isset($config) && $config['status'] == 1) {
            return self::alphanet_sms($receiver, $otp);
        }

        return 'not_found'; // Return 'not_found' if no active module worked
    }

    public static function twilio($receiver, $otp)
    {
        $config = self::get_settings('twilio');
        $response = 'error';
        if (isset($config) && $config['status'] == 1) {
            $message = str_replace("#OTP#", $otp, $config['otp_template']);
            $sid = $config['sid'];
            $token = $config['token'];
            try {
                $twilio = new Client($sid, $token);
                // Modify the receiver number format for WhatsApp
                $twilio->messages
                    ->create("whatsapp:" . $receiver, // to (WhatsApp format)
                        array(
                            // Ensure your Messaging Service SID is configured for WhatsApp,
                            // or replace with "from" => "whatsapp:<your_twilio_whatsapp_number>"
                            "messagingServiceSid" => $config['messaging_service_sid'],
                            "body" => $message
                        )
                    );
                $response = 'success';
            } catch (\Exception $exception) {
                // Log the exception for debugging?
                // error_log($exception->getMessage());
                $response = 'error';
            }
        }
        return $response;
    }

    public static function nexmo($receiver, $otp)
    {
        $config = self::get_settings('nexmo');
        $response = 'error';
        if (isset($config) && $config['status'] == 1) {
            $message = str_replace("#OTP#", $otp, $config['otp_template']);
            try {
                $ch = curl_init();

                curl_setopt($ch, CURLOPT_URL, 'https://rest.nexmo.com/sms/json');
                curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
                curl_setopt($ch, CURLOPT_POST, 1);
                curl_setopt($ch, CURLOPT_POSTFIELDS, "from=".$config['from']."&text=".$message."&to=".$receiver."&api_key=".$config['api_key']."&api_secret=".$config['api_secret']);

                $headers = array();
                $headers[] = 'Content-Type: application/x-www-form-urlencoded';
                curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);

                $result = curl_exec($ch);
                if (curl_errno($ch)) {
                    // echo 'Error:' . curl_error($ch); // Avoid echo in production
                }
                curl_close($ch);
                 // Basic check, might need refinement based on actual Nexmo success response
                 if ($result) { // Simple check if $result is not false or empty
                    $decoded_result = json_decode($result, true);
                    // Nexmo success typically has messages[0]['status'] == '0'
                    if (isset($decoded_result['messages'][0]['status']) && $decoded_result['messages'][0]['status'] == '0') {
                        $response = 'success';
                    }
                 }

            } catch (\Exception $exception) {
                 // Log exception
                $response = 'error';
            }
        }
        return $response;
    }

     public static function two_factor($receiver, $otp)
    {

        $config = self::get_settings('2factor');
        $response = 'error';
        if (isset($config) && $config['status'] == 1) {
            $apiKey = $config['api_key'];
            $otpTemplate = $config['otp_template'] ?? ''; // Use configured template or empty string
            $apiUrl = "https://2factor.in/API/V1/$apiKey/SMS/$receiver/$otp/$otpTemplate";

            $curl = curl_init();
            curl_setopt_array($curl, array(
                CURLOPT_URL => $apiUrl,
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_ENCODING => "",
                CURLOPT_MAXREDIRS => 10,
                CURLOPT_TIMEOUT => 30,
                CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_1_1,
                CURLOPT_CUSTOMREQUEST => "GET", // 2Factor uses GET for OTP sending
            ));
            $api_response = curl_exec($curl); // Capture API response
            $err = curl_error($curl);
            curl_close($curl);

            if (!$err) {
                // Check 2Factor specific success response if needed
                // Example: $decoded_response = json_decode($api_response, true); if ($decoded_response['Status'] == 'Success') ...
                $response = 'success'; // Assuming no cURL error means success for now
            } else {
                 // Log $err
                $response = 'error';
            }
        }
        return $response;
    }

     public static function msg_91($receiver, $otp)
    {
        $config = self::get_settings('msg91');
        $response = 'error';
        if (isset($config) && $config['status'] == 1) {
            $receiver = str_replace("+", "", $receiver); // Ensure receiver format is correct for msg91
            $curl = curl_init();
            curl_setopt_array($curl, array(
                CURLOPT_URL => "https://api.msg91.com/api/v5/otp?template_id=" . $config['template_id'] . "&mobile=" . $receiver . "&authkey=" . $config['auth_key'] . "",
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_ENCODING => "",
                CURLOPT_MAXREDIRS => 10,
                CURLOPT_TIMEOUT => 30,
                CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_1_1,
                CURLOPT_CUSTOMREQUEST => "POST", // Changed to POST as per msg91 v5 docs for sending OTP
                CURLOPT_POSTFIELDS => json_encode([ // Send OTP in JSON body for v5
                    "otp" => $otp,
                    // Add other parameters like "DLT_TE_ID" if required by msg91/regulations
                    ]),
                CURLOPT_HTTPHEADER => array(
                    "authkey: " . $config['auth_key'], // Auth key in header
                    "content-type: application/json"
                ),
            ));
            $api_response = curl_exec($curl);
            $err = curl_error($curl);
            curl_close($curl);
            if (!$err) {
                 // Check msg91 specific success response
                 $decoded_response = json_decode($api_response, true);
                 if (isset($decoded_response['type']) && $decoded_response['type'] == 'success') {
                     $response = 'success';
                 }
            } else {
                // Log $err
                $response = 'error';
            }
        }
        return $response;
    }

    public static function signal_wire($receiver, $otp)
    {
        $config = self::get_settings('signal_wire');
        $response = 'error';
        if (isset($config) && $config['status'] == 1) {

            $message = str_replace("#OTP#", $otp, $config['otp_template'] ?? "Your otp is #OTP#."); // Use template or default

            $ch = curl_init();
            curl_setopt($ch, CURLOPT_URL, "https://" . $config['space_url'] . "/api/laml/2010-04-01/Accounts/" . $config['project_id'] . "/Messages.json"); // Added .json for better response handling
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'POST');
            curl_setopt($ch, CURLOPT_HTTPHEADER, [
                'Accept: application/json', // Request JSON response
                'Content-Type: application/x-www-form-urlencoded',
            ]);
            curl_setopt($ch, CURLOPT_HTTPAUTH, CURLAUTH_BASIC);
            curl_setopt($ch, CURLOPT_USERPWD, $config['project_id'] . ':' . $config['token']);
            curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query([ // Use http_build_query for form data
                'From' => $config['from'],
                'To'   => $receiver,
                'Body' => $message
            ]));

            $api_response = curl_exec($ch);
            $error = curl_error($ch);
            $http_status = curl_getinfo($ch, CURLINFO_HTTP_CODE); // Get HTTP status code
            curl_close($ch);

            if (!$error && $http_status >= 200 && $http_status < 300) { // Check for success HTTP status codes
                 // Optionally check response body for status ('queued', 'sent', etc.)
                $response = 'success';
            } else {
                 // Log $error or $api_response
                $response = 'error';
            }

        }
        return $response;
    }

    public static function alphanet_sms($receiver, $otp): string
    {
        $config = self::get_settings('alphanet_sms');
        $response = 'error';
        if (isset($config) && $config['status'] == 1) {
            $receiver = str_replace("+", "", $receiver); // Ensure correct format
            $message = str_replace("#OTP#", $otp, $config['otp_template']);
            $api_key = $config['api_key'];

            $curl = curl_init();

            curl_setopt_array($curl, array(
                CURLOPT_URL => 'https://api.sms.net.bd/sendsms',
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_CUSTOMREQUEST => 'POST',
                CURLOPT_POSTFIELDS => array('api_key' => $api_key, 'msg' => $message, 'to' => $receiver),
            ));

            $api_response = curl_exec($curl); // Capture response
            $err = curl_error($curl);
            curl_close($curl);

            if (!$err) {
                 // Check alphanet specific success response if available (e.g., contains success code/message)
                 // Assuming no cURL error means success for now.
                $response = 'success';
            } else {
                 // Log $err
                $response = 'error';
            }
        }
        return $response;
    }


    public static function get_settings($name)
    {
        try {
             $config = DB::table('addon_settings')->where('key_name', $name)
            ->where('settings_type', 'sms_config')->first();

            if (isset($config) && !is_null($config->live_values)) {
                 // Added check for valid JSON before decoding
                 $decoded_values = json_decode($config->live_values, true);
                 if (json_last_error() === JSON_ERROR_NONE) {
                     return $decoded_values;
                 }
            }
        } catch (\Exception $e) {
            // Log the exception $e->getMessage()
            return null;
        }
       return null; // Return null if not found, DB error, or invalid JSON
    }
}
