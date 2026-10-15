///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'strings.g.dart';

// Path: <root>
class TranslationsEn extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsEn({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsEn _root = this; // ignore: unused_field

	@override 
	TranslationsEn $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsEn(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$app$en app = _Translations$app$en._(_root);
	@override late final _Translations$home$en home = _Translations$home$en._(_root);
	@override late final _Translations$common$en common = _Translations$common$en._(_root);
	@override late final _Translations$errors$en errors = _Translations$errors$en._(_root);
	@override late final _Translations$tabs$en tabs = _Translations$tabs$en._(_root);
}

// Path: app
class _Translations$app$en extends Translations$app$zh {
	_Translations$app$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Pure Live';
}

// Path: home
class _Translations$home$en extends Translations$home$zh {
	_Translations$home$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get recommended => 'Recommendations';
}

// Path: common
class _Translations$common$en extends Translations$common$zh {
	_Translations$common$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get confirm => 'OK';
	@override String get cancel => 'Cancel';
	@override String get retry => 'Retry';
	@override String get close => 'Close';
	@override String get save => 'Save';
	@override String get loading => 'Loading';
	@override String get empty => 'Nothing here yet';
	@override String pageOf({required int page, required int total}) => 'Page ${page} of ${total}';
}

// Path: errors
class _Translations$errors$en extends Translations$errors$zh {
	_Translations$errors$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get generic => 'Something went wrong. Please try again later.';
	@override String get network => 'Network unavailable. Check your connection and retry.';
	@override String get notFound => 'Nothing found.';
	@override String get cancelled => 'Cancelled.';
	@override String get unsupported => 'This source doesn\'t support that.';
}

// Path: tabs
class _Translations$tabs$en extends Translations$tabs$zh {
	_Translations$tabs$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get home => 'Home';
	@override String get follow => 'Follow';
	@override String get history => 'History';
	@override String get popular => 'Popular';
	@override String get settings => 'Settings';
}

/// The flat map containing all translations for locale <en>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsEn {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'app.title' => 'Pure Live',
			'home.recommended' => 'Recommendations',
			'common.confirm' => 'OK',
			'common.cancel' => 'Cancel',
			'common.retry' => 'Retry',
			'common.close' => 'Close',
			'common.save' => 'Save',
			'common.loading' => 'Loading',
			'common.empty' => 'Nothing here yet',
			'common.pageOf' => ({required int page, required int total}) => 'Page ${page} of ${total}',
			'errors.generic' => 'Something went wrong. Please try again later.',
			'errors.network' => 'Network unavailable. Check your connection and retry.',
			'errors.notFound' => 'Nothing found.',
			'errors.cancelled' => 'Cancelled.',
			'errors.unsupported' => 'This source doesn\'t support that.',
			'tabs.home' => 'Home',
			'tabs.follow' => 'Follow',
			'tabs.history' => 'History',
			'tabs.popular' => 'Popular',
			'tabs.settings' => 'Settings',
			_ => null,
		};
	}
}
