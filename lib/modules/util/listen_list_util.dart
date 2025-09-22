
import 'dart:async';

import 'package:get/get.dart';
import 'package:pure_live/core/common/core_log.dart';

final class ListenListUtil{

  static void clearStreamSubscriptionList(List<StreamSubscription> list){
    for(var s in list){
      try{
        s.cancel();
      }catch(e) {
        CoreLog.error(e);
      }
    }
    list.clear();
  }

  static void clearWorkerList(List<Worker> list){
    for(var s in list){
      try{
        s.dispose();
      }catch(e) {
        CoreLog.error(e);
      }
    }
    list.clear();
  }

}