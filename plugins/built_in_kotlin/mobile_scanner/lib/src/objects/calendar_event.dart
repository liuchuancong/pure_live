/// A calendar event extracted from a QRCode.
class CalendarEvent {
  /// Create a new [CalendarEvent] instance.
  const CalendarEvent({
    this.description,
    this.start,
    this.end,
    this.location,
    this.organizer,
    this.status,
    this.summary,
  });

  /// Create a new [CalendarEvent] instance from a map.
  factory CalendarEvent.fromNative(Map<Object?, Object?> data) {
    return CalendarEvent(
      description: data['description'] as String?,
      start: DateTime.tryParse(data['start'] as String? ?? ''),
      end: DateTime.tryParse(data['end'] as String? ?? ''),
      location: data['location'] as String?,
      organizer: data['organizer'] as String?,
      status: data['status'] as String?,
      summary: data['summary'] as String?,
    );
  }

  /// The description of the calendar event.
  final String? description;

  /// The start time of the calendar event.
  final DateTime? start;

  /// The end time of the calendar event.
  final DateTime? end;

  /// The location of the calendar event.
  final String? location;

  /// The organizer of the calendar event.
  final String? organizer;

  /// The status of the calendar event.
  final String? status;

  /// The summary of the calendar event.
  final String? summary;
}
