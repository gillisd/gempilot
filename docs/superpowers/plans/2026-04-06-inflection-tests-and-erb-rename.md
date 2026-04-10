# Inflection Tests and ERB Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add unit tests for `String::Inflectable` and rename `version.rake.erb` to `version.rake` since it no longer contains ERB tags.

**Architecture:** Two independent tasks. Task 1 adds an RSpec spec for the inflection refinement covering `camelize`, `underscore`, and `dasherize` with edge cases. Task 2 renames the template file and switches `gem_builder.rb` from `erb` to `cp`.

**Tech Stack:** Ruby, RSpec

---

## File Structure

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `spec/core_ext/string/inflectable_spec.rb` | Unit tests for inflection refinement |
| Rename | `data/templates/gem/rakelib/version.rake.erb` → `data/templates/gem/rakelib/version.rake` | Remove misleading ERB extension |
| Modify | `lib/gempilot/cli/gem_builder.rb:48` | Switch from `erb` to `cp` for version.rake |

---

### Task 1: Add inflection unit tests

**Files:**
- Create: `spec/core_ext/string/inflectable_spec.rb`

- [ ] **Step 1: Write the spec**

```ruby
require_relative "../../lib/core_ext/string/refinements/inflectable"

using String::Inflectable

RSpec.describe String::Inflectable do
  describe "#camelize" do
    it "camelizes a snake_case string" do
      expect("my_gem".camelize).to eq("MyGem")
    end

    it "camelizes a path with slashes into namespaces" do
      expect("my/gem".camelize).to eq("My::Gem")
    end

    it "handles a single word" do
      expect("gem".camelize).to eq("Gem")
    end

    it "handles a hyphenated string" do
      expect("my-gem".camelize).to eq("MyGem")
    end

    it "preserves numeric segments" do
      expect("v_2".camelize).to eq("V_2")
    end
  end

  describe "#underscore" do
    it "underscores a CamelCase string" do
      expect("MyGem".underscore).to eq("my_gem")
    end

    it "underscores consecutive capitals" do
      expect("CLI".underscore).to eq("cli")
    end

    it "underscores mixed case with acronyms" do
      expect("HTTPClient".underscore).to eq("http_client")
    end

    it "preserves existing underscores" do
      expect("my_gem".underscore).to eq("my_gem")
    end

    it "converts hyphens to underscores" do
      expect("my-gem".underscore).to eq("my_gem")
    end
  end

  describe "#dasherize" do
    it "converts underscores to hyphens" do
      expect("my_gem".dasherize).to eq("my-gem")
    end

    it "leaves non-underscored strings alone" do
      expect("mygem".dasherize).to eq("mygem")
    end
  end

  describe "class method form" do
    it "camelizes via String.camelize" do
      expect(String.camelize("my_gem")).to eq("MyGem")
    end

    it "underscores via String.underscore" do
      expect(String.underscore("MyGem")).to eq("my_gem")
    end

    it "dasherizes via String.dasherize" do
      expect(String.dasherize("my_gem")).to eq("my-gem")
    end
  end
end
```

- [ ] **Step 2: Run the spec**

Run: `bundle exec rspec spec/core_ext/string/inflectable_spec.rb --format documentation`
Expected: All examples pass

- [ ] **Step 3: Run rubocop**

Run: `bundle exec rubocop spec/core_ext/string/inflectable_spec.rb`
Expected: No offenses

- [ ] **Step 4: Commit**

```bash
git add spec/core_ext/string/inflectable_spec.rb
git commit -m "Add unit tests for String::Inflectable refinement"
```

---

### Task 2: Rename version.rake.erb to version.rake

**Files:**
- Rename: `data/templates/gem/rakelib/version.rake.erb` → `data/templates/gem/rakelib/version.rake`
- Modify: `lib/gempilot/cli/gem_builder.rb:48`

- [ ] **Step 1: Rename the template file**

```bash
git mv data/templates/gem/rakelib/version.rake.erb data/templates/gem/rakelib/version.rake
```

- [ ] **Step 2: Update `gem_builder.rb`**

In `lib/gempilot/cli/gem_builder.rb` line 48, change:

```ruby
        erb "rakelib/version.rake.erb", "#{@gem_name}/rakelib/version.rake"
```

To:

```ruby
        cp "rakelib/version.rake", "#{@gem_name}/rakelib/version.rake"
```

- [ ] **Step 3: Run tests**

Run: `bundle exec rake test spec`
Expected: All pass

- [ ] **Step 4: Run rubocop**

Run: `bundle exec rubocop`
Expected: No offenses

- [ ] **Step 5: Commit**

```bash
git add data/templates/gem/rakelib/version.rake lib/gempilot/cli/gem_builder.rb
git commit -m "Rename version.rake.erb to version.rake — no ERB tags remain"
```
