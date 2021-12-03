#![cfg_attr(target_os = "nanos", no_std)]
#[cfg(all(target_os = "nanos", feature = "speculos"))]
use nanos_sdk::debug_print;
use core::fmt::Write;

pub struct DBG;

#[cfg(all(target_os = "nanos", feature = "speculos"))]
impl Write for DBG {
    fn write_str(&mut self, s: &str) -> core::fmt::Result {
        use arrayvec::ArrayString;
        // Dunno why the copy is required, might be some pic issue as this is going straight to
        // assembly.
        for c in s.chars() {
            let mut qq = ArrayString::<1>::new();
            qq.push(c);
            debug_print(qq.as_str());
        }
        Ok(())
    }
}

#[cfg(all(target_os = "nanos", not(feature = "speculos")))]
impl Write for DBG {
    fn write_str(&mut self, _s: &str) -> core::fmt::Result {
        Ok(())
    }
}

#[cfg(not(target_os = "nanos"))]
impl Write for DBG {
    fn write_str(&mut self, _s: &str) -> core::fmt::Result {
        print!("{}", _s);
        Ok(())
    }
}

#[cfg(not(all(target_os = "nanos", not(feature = "speculos"))))]
#[macro_export]
macro_rules! log {
    (target: $target:expr, $lvl:expr, $fmt:literal $($arg:tt)*) => ({
        use core::fmt::Write;
        let _ = core::write!($crate::DBG, concat!("{}:{}: ", $fmt, "\n"), core::file!(), core::line!() $($arg)*);
    });
    ($lvl:expr, $fmt:literal $($arg:tt)*) => (log!(target: __log_module_path!(), $lvl, $fmt $($arg)*))
}

#[cfg(all(target_os = "nanos", not(feature = "speculos")))]
#[macro_export]
macro_rules! log {
    (target: $target:expr, $lvl:expr, $fmt:literal $($arg:tt)*) => ({ });
    ($lvl:expr, $fmt:literal $($arg:tt)*) => (log!(target: __log_module_path!(), $lvl, $fmt $($arg)*))
}

#[cfg(feature = "log_error")]
#[macro_export]
macro_rules! error {
    ($fmt:literal $($arg:tt)*) => ({use $crate::log; log!("ERROR", $fmt $($arg)*)})
}
#[cfg(not(feature = "log_error"))]
#[macro_export]
macro_rules! error {
    ($fmt:literal $($arg:tt)*) => ({ })
}
#[cfg(feature = "log_warn")]
#[macro_export]
macro_rules! warn {
    ($fmt:literal $($arg:tt)*) => ({use $crate::log; log!("WARN", $fmt $($arg)*)})
}
#[cfg(not(feature = "log_warn"))]
#[macro_export]
macro_rules! warn {
    ($fmt:literal $($arg:tt)*) => ({ })
}
#[cfg(feature = "log_info")]
#[macro_export]
macro_rules! info {
    ($fmt:literal $($arg:tt)*) => ({use $crate::log; log!("INFO", $fmt $($arg)*)})
}
#[cfg(not(feature = "log_info"))]
#[macro_export]
macro_rules! info {
    ($fmt:literal $($arg:tt)*) => ({ })
}
#[cfg(feature = "log_debug")]
#[macro_export]
macro_rules! debug {
    ($fmt:literal $($arg:tt)*) => ({use $crate::log; log!("DEBUG", $fmt $($arg)*)})
}
#[cfg(not(feature = "log_debug"))]
#[macro_export]
macro_rules! debug {
    ($fmt:literal $($arg:tt)*) => ({ })
}
#[cfg(feature = "log_trace")]
#[macro_export]
macro_rules! trace {
    ($fmt:literal $($arg:tt)*) => ({use $crate::log; log!("TRACE", $fmt $($arg)*)})
}
#[cfg(not(feature = "log_trace"))]
#[macro_export]
macro_rules! trace {
    ($fmt:literal $($arg:tt)*) => ({ })
}

#[test]
fn test_debug() {
  debug!("FOO FOO FOO\n");
  assert_eq!(true, false);
}
