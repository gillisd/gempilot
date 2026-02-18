## BUGS

1. Calling "rake" immediately after creating new gem results in "rubocop-performance" is missing. All gems should have already been installed.

2. Change test to ensure '# frozen_string_literal' is NOT created. It only complicates things and is no longer needed in ruby > 3.4. Remove all generation related code around adding this magic tag.

## DESIGN ISSUES

The current gempilot add feature is not ergonomic. Someone working in ruby is not thinking about files, they are thinking about constants. Since we are using zeitwerk everything is standardized. Interface should look like

1. when entered: `gempilot add class MyGem::SomeNameSpace::NewClass`
2. it creates: `lib/my_gem/some_name_space/new_class.rb`
3. with body:

```ruby
module MyGem
  module SomeNameSpace
    class NewClass
    end
  end
end


```

^ Ensure this or something like it is a test case, and repeat as applicable for other constant types.
