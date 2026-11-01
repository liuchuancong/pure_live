/// File transfer: chunked, resumable, hash-verified end to end, committed
/// atomically (spec §13).
///
/// The receiving side is a server (`FileReceiver.attachTo`); the sending
/// side is `FileSender.send` over a `PeerFileChannel`. Every path is
/// the receiver's own decision; a peer sends bytes and names, never paths.
library;

export 'file_receiver.dart';
export 'file_sender.dart';
export 'peer_file_channel.dart';
