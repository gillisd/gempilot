TODOS

1. exe breaks due ot patherror when calling from outside of project dir. I get error when I call
/some/long/path/gempilot/exe/gempilot new

2. The interactive experience is lacking. Take alook at bundler's, which uses colors, and shows examples for each prompt:

```
Creating gem 'foo'...

Do you want to set up continuous integration for your gem? Supported services:
* CircleCI:       https://circleci.com/
* GitHub Actions: https://github.com/features/actions
* GitLab CI:      https://docs.gitlab.com/ee/ci/
Future `bundle gem` calls will use your choice. This setting can be changed anytime with `bundle config gem.ci`.
Enter a CI service. github/gitlab/circle/(none): none

Using a MIT license means that any other developer or company will be legally allowed to use your code for free as long as they admit you created it. You can read more about the MIT license at https://choosealicense.com/licenses/mit.
Do you want to license your code permissively under the MIT license? y/(n): n

Codes of conduct can increase contributions to your project by contributors who prefer safe, respectful, productive, and collaborative spaces.
See https://github.com/ruby/rubygems/blob/master/CODE_OF_CONDUCT.md
Do you want to include a code of conduct in gems you generate? y/(n): n

A changelog is a file which contains a curated, chronologically ordered list of notable changes for each version of a project. To make it easier for users and contributors to see precisely what notable changes have been made between each release (or version) of the project. Whether consumers or developers, the end users of software are human beings who care about what's in the software. When the software changes, people want to know why and how. see https://keepachangelog.com
Do you want to include a changelog? y/(n): n

Do you want to add a code linter and formatter to your gem? Supported Linters:
* RuboCop:       https://rubocop.org
* Standard:      https://github.com/standardrb/standard
Future `bundle gem` calls will use your choice. This setting can be changed anytime with `bundle config gem.linter`.
Enter a linter. rubocop/standard/(none): n

Initializing git repo in /Users/davidgillis/repos/tries/2026-02-16-misc/gempilot/misc-updates/foo
      create  foo/Gemfile
            create  foo/lib/foo.rb
                  create  foo/lib/foo/version.rb
                        create  foo/sig/foo.rbs
                              create  foo/foo.gemspec
                                    create  foo/Rakefile
                                          create  foo/README.md
                                                create  foo/bin/console
                                                      create  foo/bin/setup
                                                            create  foo/.gitignore
                                                                  create  foo/test/test_helper.rb
                                                                        create  foo/test/test_foo.rb

                                                                        Gem 'foo' was successfully created. For more information on making a RubyGem visit https://bundler.io/guides/creating_gem.html
                                                                        ```

