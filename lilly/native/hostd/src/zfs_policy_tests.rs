use crate::zfs_policy::{mutation, Scope};
use hegel::{generators as gs, TestCase};

/// A dataset created beneath a configured pool is accepted, while the pool
/// itself is never a mutation target. This keeps the grammar's strict-
/// descendant boundary true across arbitrary valid dataset components.
#[hegel::test]
fn descendant_boundary_is_preserved(tc: TestCase) {
    let pool_component = tc.draw(hegel::one_of!(
        gs::just("pool".to_owned()),
        gs::just("data_1".to_owned()),
        gs::just("a-b".to_owned()),
    ));
    let child_component = tc.draw(hegel::one_of!(
        gs::just("child".to_owned()),
        gs::just("vm_2".to_owned()),
        gs::just("x:y".to_owned()),
    ));
    let pool = format!("zroot/{pool_component}");
    let child = format!("{pool}/{child_component}");
    let datasets = vec![pool.as_bytes().to_vec()];
    let scope = Scope {
        datasets: &datasets,
        paths: &[],
    };

    let pool_bytes = pool.as_bytes();
    let child_bytes = child.as_bytes();
    assert!(!mutation(&[b"create", pool_bytes], &scope));
    assert!(mutation(&[b"create", child_bytes], &scope));
    assert!(mutation(&[b"destroy", child_bytes], &scope));
}
