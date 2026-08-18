# Alba::Inertia

[![Gem Version](https://badge.fury.io/rb/alba-inertia.svg)](https://rubygems.org/gems/alba-inertia)

Seamless integration between [Alba](https://github.com/okuramasafumi/alba) serializers and [Inertia Rails](https://inertia-rails.dev/).

## Features

- Support for all Inertia prop types: optional, deferred, and merge props
- Lazy evaluation for efficient data loading on partial reloads
- Auto-detection of resource classes based on controller/action naming
- Instance variables as shared props in `inertia_share` blocks

<br/>

<img src="https://cdn.evilmartians.com/badges/logo-no-label.svg" alt="Evil Martians logo" width="22" height="16" /> <b>Alba::Inertia</b> is built by <b><a href="https://evilmartians.com/">Evil Martians</a></b>, an American design and engineering consultancy for <b>developer tools, AI, and cybersecurity startups</b>.

## Installation

Add to your Gemfile:

```ruby
gem "alba"
gem "inertia_rails"
gem "alba-inertia"
```

## Usage

### Basic Setup

Include `Alba::Inertia::Resource` in your resource classes:

```ruby
class ApplicationResource
  include Alba::Resource
  
  # ...

  helper Alba::Inertia::Resource
end
```

Include `Alba::Inertia::Controller` in your controllers:

```ruby
class InertiaController < ApplicationController
  include Alba::Inertia::Controller
end
```

### Defining Inertia Props

#### Inline `inertia:` option (recommended)

```ruby
class CoursesIndexResource < ApplicationResource
  # Simple attributes
  attributes :id, :title

  # Optional prop (loaded only when requested)
  has_many :courses, serializer: CourseResource, inertia: :optional

  # Deferred prop (loaded in separate request)
  has_many :students, serializer: StudentResource, inertia: :defer

  # Deferred with options
  attribute :stats, inertia: { defer: { group: 'analytics', merge: true } } do |object|
    expensive_calculation(object)
  end

  # Merge prop (for partial reloads)
  has_many :comments, serializer: CommentResource, inertia: { merge: { match_on: :id } }

  # Scroll prop with auto-detection.
  # Checks object for `scroll_meta` and `pagy` attributes, or object being a Kaminari collection.
  has_many :items, inertia: :scroll

  # Scroll prop with explicit metadata
  has_many :items, inertia: { scroll: :meta }
  has_many :items, inertia: { scroll: ->(obj) { obj.meta } }
  has_many :items, inertia: { scroll: ->(obj) { obj.meta }, wrapper: 'data' }

  # Once prop
  has_many :plans, inertia: :once
  has_many :plans, inertia: { once: { key: 'active_plans', expires_in: 1.hour, fresh: ->(obj) { obj.fresh? } } }
end
```

#### Separate `inertia_prop` declaration

```ruby
class CoursesIndexResource < ApplicationResource
  has_many :courses, serializer: CourseResource
  inertia_prop :courses, optional: true

  attribute :stats
  inertia_prop :stats, defer: { merge: true, group: 'analytics' }
end
```

### Controller Integration

```ruby
class CoursesController < InertiaController
  def index
    @courses = Course.all
    @current_category_id = params[:category_id]
    # Auto-detects CoursesIndexResource and passes instance variables
  end

  def show
    @course = Course.find(params[:id])

    # With a custom component
    render_inertia "Courses/Show"
  end

  def create
    @course = Course.new(course_params)

    if @course.save
      redirect_to courses_path
    else
      # With errors
      render_inertia inertia: { errors: user.errors }
    end
  end
end
```

### Shared Data

Inertia Rails' [shared data](https://inertia-rails.dev/guide/shared-data) blocks have to return a hash. Alba::Inertia lets them assign instance variables instead, matching the way controller actions pass data to resources:

```ruby
class EventsController < InertiaController
  # Static sharing: evaluated immediately
  inertia_share app_name: Rails.configuration.app_name

  # Dynamic sharing: evaluated at render time
  inertia_share do
    if user_signed_in?
      @user = current_user.as_json(only: [:id, :name, :email])
      @notifications = current_user.unread_notifications_count
    end
  end

  # Lazily evaluated values
  inertia_share do
    @total_users = -> { User.count }
  end
end
```

Every instance variable assigned in the block becomes a shared prop with the `@` stripped (`@user` => `user`). Values are passed to Inertia untouched, so lambdas and prop helpers (`InertiaRails.defer`, `InertiaRails.optional`, ...) keep working.

The same applies to the instance-level `inertia_share`, useful in `before_action` callbacks:

```ruby
class EventsController < InertiaController
  before_action :share_event

  private

  def share_event
    inertia_share { @event = Event.find(params[:id]).as_json }
  end
end
```

A few things to keep in mind:

- The block is evaluated by a collector standing in for the controller: method calls (`current_user`, `params`, ...) are delegated to it, but assignments stay inside the block, so they don't end up in `view_assigns` (and thus in your resource's locals).
- Instance variables set before the block runs (in a `before_action`, for example) can be read inside it, and only become props if the block assigns them a new value.
- Blocks returning a hash keep working as before. A block that assigns instance variables ignores its return value, since `@user = ...` as the last expression would otherwise return the assigned value as the block's result.
- Instance variables starting with an underscore (`@_internal`) are never shared.

### Serialization Modes

#### `.to_inertia` - For Inertia.js rendering

Returns lazy procs and Inertia prop objects:

```ruby
resource = CoursesIndexResource.new(courses: @courses)
resource.to_inertia
# => { "courses" => <InertiaRails::OptionalProp>, "stats" => <Proc> }
```

#### `.as_json` - For standard JSON

Returns normal data (Typelizer, API endpoints):

```ruby
resource = CoursesIndexResource.new(courses: @courses)
resource.as_json
# => { "courses" => [...], "stats" => 42 }
```

### Inheritance

Metadata is inherited from parent resources:

```ruby
class BaseResource < ApplicationResource
  attribute :created_at, inertia: :optional
end

class CourseResource < BaseResource
  attributes :id, :title
  # Inherits created_at with optional: true
end
```

Child can override parent metadata:

```ruby
class ExtendedCourseResource < CourseResource
  inertia_prop :created_at, defer: true  # Override parent's optional: true
end
```

## Configuration

```ruby
Alba::Inertia.configure do |config|
  # Render with Alba resource class by default
  config.default_render = true

  # Wrap all props in lambdas by default
  config.lazy_by_default = true
end
```

## Advanced Usage

### Custom Serializer Selection

```ruby
render_inertia(serializer: CustomResource)
```

### Custom Props

```ruby
render_inertia(locals: { custom: 'props'})
```

### Serializer Params

You can pass params to the serializer using the `serializer_params` option. This is useful for passing context like the current user, permissions, or feature flags:

```ruby
class CoursesController < InertiaController
  def index
    @courses = Course.all
    render_inertia(serializer_params: { current_user: current_user })
  end
end
```

In your resource, access params via the `params` method:

```ruby
class CoursesIndexResource < ApplicationResource
  attributes :id, :title

  attribute :can_edit do |course|
    params[:current_user]&.can_edit?(course)
  end
end
```

### Default Serializer Params

Override `inertia_serializer_params` in your controller to provide default params for all Inertia renders:

```ruby
class ApplicationController < ActionController::Base
  include Alba::Inertia::Controller

  private

  def inertia_serializer_params
    { current_user: current_user, locale: I18n.locale }
  end
end
```

The `serializer_params` option in `render_inertia` will be merged with these defaults (with `serializer_params` taking precedence).

## Naming Convention

The controller integration follows Rails conventions:

```ruby
# Controller: CoursesController
# Action: index
# Expected Resource: CoursesIndexResource or CoursesIndexSerializer 

# Controller: Admin::UsersController
# Action: show
# Expected Resource: Admin::UsersShowResource or Admin::UsersShowSerializer
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/skryukov/alba-inertia.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
