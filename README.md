# Backtrace error submission gem

# Installation

Add `gem 'backtraceio'` to your Gemfile. Alternatively, install it yourself:
```
gem install backtraceio
```

# Usage

```ruby
require 'backtraceio'
```

## Global crash handler

Pass your custom token and upload url from your Backtrace
account.

```ruby
BacktraceIO.register_error_handler(TOKEN, URL)
```

## Reporting custom errors

Create a new `Report` object.

```ruby
report = BacktraceIO::Report
```

(Optional) Add custom attributes/annotations/exception objects:

```ruby
report.attributes['cpu.cores'] = 8
report.annotations['Current User'] = { name: 'John', uid: 42 }
# if we're in an exception handler
report.add_exception_data current_exception
```

The format for attributes and annotations can be found in
[Backtrace I/O api docs][1].

Submit the crash. Pass your custom token and upload url from your Backtrace
account.

```ruby
st = BacktraceIO::SubmissionTarget.new TOKEN, URL
st.submit report.to_hash
```

[1]: https://api.backtrace.io/#tag/submit-crash
