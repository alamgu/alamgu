#![no_std]
#![feature(try_trait)]

use nanos_sdk::buttons::{ButtonsState, ButtonEvent};
use nanos_ui::bagls::*;
use nanos_ui::ui::{get_event, MessageValidator, SingleMessage};
use arrayvec::ArrayString;
use core::fmt::Write;
use ledger_log::trace;

#[derive(Debug)]
pub struct PromptWrite<'a, const N: usize> {
    offset: usize,
    buffer: &'a mut ArrayString<N>,
    total: usize
}

impl<'a, const N: usize> Write for PromptWrite<'a, N> {
    fn write_str(&mut self, s: &str) -> core::fmt::Result {
        self.total += s.len();
        let offset_in_s = core::cmp::min(self.offset, s.len());
        self.offset -= offset_in_s;
        if self.offset > 0 {
            return Ok(());
        }
        let rv = self.buffer.try_push_str(
            &s[offset_in_s .. core::cmp::min(s.len(), offset_in_s + self.buffer.remaining_capacity())]
        ).map_err(|_| core::fmt::Error);
        rv
    }
}

pub fn final_accept_prompt(prompt: &[&str]) -> Option<()> {
    if !MessageValidator::new(prompt, &[&"Confirm"], &[&"Reject"]).ask() {
        trace!("User rejected at end\n");
        None
    } else {
        trace!("User accepted");
        Some(())
    }
}

pub struct ScrollerError;
impl From<core::fmt::Error> for ScrollerError {
    fn from(_: core::fmt::Error) -> Self {
        ScrollerError
    }
}
impl From<core::str::Utf8Error> for ScrollerError {
    fn from(_: core::str::Utf8Error) -> Self {
        ScrollerError
    }
}
impl From<core::option::NoneError> for ScrollerError {
    fn from(_: core::option::NoneError) -> Self {
        ScrollerError
    }
}

#[inline(never)]
pub fn write_scroller< F: for <'b> Fn(&mut PromptWrite<'b, 16>) -> Result<(), ScrollerError> > (title: &str, prompt_function: F) -> Option<()> {
    if !WriteScroller::<_, 16>::new(title, prompt_function).ask() {
        trace!("User rejected prompt");
        None
    } else {
        Some(())
    }
}

pub struct WriteScroller<'a, F: for<'b> Fn(&mut PromptWrite<'b, CHAR_N>) -> Result<(), ScrollerError>, const CHAR_N: usize> {
    title: &'a str,
    contents: F
}

const RIGHT_CHECK : Icon = Icon::new(Icons::Check).pos(120,12);

impl<'a, F: for<'b> Fn(&mut PromptWrite<'b, CHAR_N>) -> Result<(), ScrollerError>, const CHAR_N: usize> WriteScroller<'a, F, CHAR_N> {

    pub fn new(title: &'a str, contents: F) -> Self {
        WriteScroller { title, contents }
    }

    fn get_length(&self) -> Result<usize, ScrollerError> {
        let mut buffer = ArrayString::new();
        let mut prompt_write = PromptWrite{ offset: 0, buffer: &mut buffer, total: 0 };
        (self.contents)(&mut prompt_write)?;
        let length = prompt_write.total;
        trace!("Prompt length: {}", length);
        Ok(length)
    }

    pub fn ask(&self) -> bool {
        self.ask_err().unwrap_or(false)
    }

    pub fn ask_err(&self) -> Result<bool, ScrollerError> {
        let mut buttons = ButtonsState::new();
        let page_count = (core::cmp::max(1, self.get_length()?)-1) / CHAR_N + 1;
        if page_count == 0 {
            return Ok(true);
        }
        if page_count > 1000 {
            trace!("Page count too large: {}", page_count);
            panic!("Page count too large: {}", page_count);
        }
        let title_label = LabelLine::new().pos(0, 10).text(self.title);
        let label = LabelLine::new().pos(0,25); 
        let mut cur_page = 0;

        // A closure to draw common elements of the screen
        // cur_page passed as parameter to prevent borrowing
        let draw = |page: usize| -> Result<(), ScrollerError> {
            let offset = page * CHAR_N;
            let mut buffer = ArrayString::new();
            (self.contents)(&mut PromptWrite{ offset, buffer: &mut buffer, total: 0 })?;
            title_label.display();
            label.text(buffer.as_str()).paint();
            trace!("Prompting with ({} of {}) {}: {}", page, page_count, self.title, buffer);
            if page > 0 {
                LEFT_ARROW.paint();
            }
            if page + 1 < page_count {
                RIGHT_ARROW.paint();
            } else {
                RIGHT_CHECK.paint();
            }
            Ok(())
        };

        draw(cur_page)?;

        loop {
            match get_event(&mut buttons) {
                Some(ButtonEvent::LeftButtonPress) => {
                    LEFT_S_ARROW.paint();
                }
                Some(ButtonEvent::RightButtonPress) => {
                    RIGHT_S_ARROW.paint();
                }
                Some(ButtonEvent::LeftButtonRelease) => {
                    if cur_page > 0 {
                        cur_page -= 1;
                    }
                    // We need to draw anyway to clear button press arrow
                    draw(cur_page)?;
                }    
                Some(ButtonEvent::RightButtonRelease) => {
                    if cur_page < page_count {
                        cur_page += 1;
                    }
                    if cur_page == page_count {
                        break Ok(true);
                    }
                    // We need to draw anyway to clear button press arrow
                    draw(cur_page)?;
                }
                Some(ButtonEvent::BothButtonsRelease) => break Ok(false),
                Some(_) | None => ()
            }
        }
    }
}

pub struct RootMenu<'a, const N: usize> {
    screens: [&'a str; N],
    state: usize,
}

impl<'a, const N: usize> RootMenu<'a, N> {
    pub fn new(screens: [&'a str; N]) -> RootMenu<'a, N> {
        RootMenu {
            screens,
            state: 0
        }
    }

    #[inline(never)]
    pub fn show(&self) {
        SingleMessage::new(self.screens[self.state]).show();
    }

    #[inline(never)]
    pub fn update(&mut self, btn: ButtonEvent) -> Option<usize> {
        match btn {
            ButtonEvent::LeftButtonRelease => self.state = if self.state > 0 { self.state - 1 } else {0},
            ButtonEvent::RightButtonRelease => self.state = core::cmp::min(self.state+1, N-1),
            ButtonEvent::BothButtonsRelease => return Some(self.state),
            _ => (),
        }
        None
    }
}
