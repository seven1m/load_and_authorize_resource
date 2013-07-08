# Load And Authorize Resource

Auto-loads and authorizes resources in Rails 3 and up.

This was inspired heavily by functionality in the [CanCan](https://github.com/ryanb/cancan) gem, but extracted to work mostly independent of any authorization library.

## Loading and Authorizing the Resource

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

For each controller action, `current_user.can_<action>?(@note)` is consulted. If false, then an `LoadAndAuthorizeResoruce::AccessDenied` error is raised.

This works very nicely along with the [Authority](https://github.com/nathanl/authority) gem.

## Loading and Authorizing the Parent Resource

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

For parent resources, `current_user.can_read?(@parent)` is consulted. If false, then an `LoadAndAuthorizeResoruce::AccessDenied` error is raised.

If none of the parent IDs are present, e.g. `person_id` and `group_id` are both absent in `params`, then a `LoadAndAuthorizeResoruce::ParameterMissing` exception is raised.

### Shallow Routes

You can make the parent loading and authorization optional by setting the `shallow` option:

```ruby
class NotesController < ApplicationController
  load_and_authorize_parent :person, :group, shallow: true
end
```

...this will allow all of the following URLs to work:

* `/people/1/notes/2` - `@person` will be set and authorized for reading
* `/groups/1/notes/2` - `@group` will be set and authorized for reading
* `/notes/2` - no parent will be set

## Rescuing Exceptions

You are encouraged to rescue the two possible exceptions in your ApplicationController, like so:

```ruby
class ApplicationController < ActionController::Base
  rescue_from 'LoadAndAuthorizeResoruce::AccessDenied', 'LoadAndAuthorizeResoruce::ParameterMissing' do |exception|
    render text: 'not authorized', status: :forbidden
  end
end
```

## Author

Made with ❤ by [Tim Morgan](http://timmorgan.org).

Licensed under MIT license. Please use it, fork it, make it more awesome.
