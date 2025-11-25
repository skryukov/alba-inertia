# Alba::Inertia

Seamless integration between [Alba](https://github.com/okuramasafumi/alba) serializers and [Inertia Rails](https://inertia-rails.dev/).

## Features

- Support for all Inertia prop types: optional, deferred, and merge props
- Lazy evaluation for efficient data loading on partial reloads
- Auto-detection of resource classes based on controller/action naming

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
  has_many :items, inertia: { scroll: -> { |obj| obj.meta } }
  has_many :items, inertia: { scroll: -> { |obj| obj.meta }, wrapper: 'data' }
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
