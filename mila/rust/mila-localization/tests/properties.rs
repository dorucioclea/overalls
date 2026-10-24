use hegel::{generators as gs, TestCase};
use mila_localization::{direction, normalize, Direction, Locale, SUPPORTED_LOCALES};

#[hegel::test(test_cases = 128)]
fn normalized_locale_is_canonical_or_rejected(tc: TestCase) {
    let input = String::from_utf8_lossy(&tc.draw(gs::vecs(gs::default::<u8>()).max_size(200))).into_owned();
    match normalize(&input) {
        Some(canonical) => {
            assert!(SUPPORTED_LOCALES.contains(&canonical.as_str()));
            assert_eq!(Locale::parse(&canonical).unwrap().as_str(), canonical);
            assert!(canonical.is_ascii());
        }
        None => {
            // Rejection must be deterministic: parsing the same input cannot succeed.
            assert!(Locale::parse(&input).is_none());
        }
    }
}

#[hegel::test(test_cases = 128)]
fn locale_direction_is_total_and_stable(tc: TestCase) {
    let input = String::from_utf8_lossy(&tc.draw(gs::vecs(gs::default::<u8>()).max_size(200))).into_owned();
    let first = direction(&input);
    let second = direction(&input);
    assert_eq!(first, second);
    if let Some(locale) = Locale::parse(&input) {
        if matches!(locale.as_str(), "ar" | "arz" | "ur") {
            assert_eq!(first, Direction::Rtl);
        } else {
            assert_eq!(first, Direction::Ltr);
        }
    } else {
        assert_eq!(first, Direction::Ltr);
    }
}
