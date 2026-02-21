/// Error types returned by TrustCore operations.
enum FaceVerifyError {
  noFaceDetected,
  multipleFaces,
  eyesClosed,
  notLookingAtCamera,
  tooFarFromCamera,
  livenessCheckFailed,
  livenessTimeout,
  cameraPermissionDenied,
  userCancelled,
  noReferenceImage,
  invalidReferenceImage,
  internalError,
}
