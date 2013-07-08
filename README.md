# Load And Authorize Resource

Auto-loads and authorizes resources in Rails 3 and up.

This was inspired heavily by functionality in the [CanCan](https://github.com/ryanb/cancan) gem, but extracted to work mostly independent of any authorization library.

## Loading and authorizing the resource.

```ruby
class NotesController < ApplicationController
  load_and_authorize_resource

  def show
    # @note is already loaded
  end

  def new
    # @note is a new Note instance
  end

  def create
    # @note is a new Note instance
    # with attributes set from note_params
  end
end
```

For each controller action, `current_user.can_<action>?(@note)` is consulted. If false, then an `ActionController::ParameterMissing` error is raised.

This works very nicely along with the [Authority](https://github.com/nathanl/authority) gem.

## Loading and authorizing the parent resource.

Also loads and authorizes the parent resource(s)... given the following routes:

```ruby
My::Application.routes.draw do
  resources :people do
    resources :notes
  end

  resources :groups do
    resources :notes
  end
end
```

... you can do this in your controller:

```ruby
class NotesController < ApplicationController
  load_and_authorize_parent :person, :group
  load_and_authorize_resource

  def show
    # for /people/1/notes/2
    # @parent = @person = Person.find(1)
    # for /groups/1/notes/2
    # @parent = @group = Group.find(1)
  end
end
```

For parent resources, `current_user.can_read?(@parent)` is consulted. If false, then an `ActionController::ParameterMissing` error is raised.
