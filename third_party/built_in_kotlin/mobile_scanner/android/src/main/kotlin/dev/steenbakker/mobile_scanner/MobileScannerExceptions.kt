package dev.steenbakker.mobile_scanner

class NoCamera : Exception()
class AlreadyStarted : Exception()
class AlreadyStopped : Exception()
class AlreadyPaused : Exception()
class CameraError : Exception()
class ZoomWhenStopped : Exception()
class ZoomNotInRange : Exception()