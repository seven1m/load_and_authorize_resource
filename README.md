# Load And Authorize Resource

Auto-loads and authorizes resources in Rails 3 and up.

This was inspired heavily by functionality in the [CanCan](https://github.com/ryanb/cancan) gem, but built to work mostly independent of any authorization library.

[Documentation](http://rubydoc.info/github/seven1m/load_and_authorize_resource/master/frames)

## Mascot

This is LAAR. He's a horse my daughter drew.

![LAAR](https://raw.github.com/seven1m/load_and_authorize_resource/master/mascot.png)

## Assumptions

This library assumes your app follows some (fairly common) conventions:

1. Your controller name matches your model name, e.g. "NotesController" for the "Note" model.
2. You have a method on your (Application)Controller called `current_user` that returns your User model.
3. Your User model has methods like `can_read?`, `can_update?`, `can_delete?`, etc. (This works great with [Authority](https://github.com/nathanl/authority) gem, but naturally can work with any authorization library, given you/it defines those methods.)
4. You have a method on your controller that returns the resource parameters, e.g. `note_params`. You're probably already doing this if you're using [StrongParameters](https://github.com/rails/strong_parameters) or Rails 4.

## Installing

Add to your Gemfile:

```
gem 'load_and_authorize_resource'
```

...and run `bundle install`.

Then add the following to your ApplicationController:

```ruby
class ApplicationController < ActionController::Base
  include LoadAndAuthorizeResource
end
```

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

For each controller action, `current_user.can_<action>?(@note)` is consulted. If false, then an `LoadAndAuthorizeResource::AccessDenied` error is raised.

This works very nicely along with the [Authority](https://github.com/nathanl/authority) gem.

If you don't wish to authorize, or if you wish to do the loading yourself, you can just call `load_resource` and/or `authorize_resource`. Also, each macro accepts the normal before_filter options such as `:only` and `:except` if you wish to only apply the filters to certain actions.

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

If you don't wish to authorize, or if you wish to do the loading yourself, you can just call `load_parent` and/or `authorize_parent`. Also, each macro accepts the normal before_filter options such as `:only` and `:except` if you wish to only apply the filters to certain actions.

### Accessing Children

When you setup to load a parent resoure, a private method is defined with the name of the child resource that returns an ActiveRecord::Relation scoped to the `@parent` (if present). It basically looks like this:

```ruby
class NotesController < ApplicationController

  private

  def notes
    if @person
      @person.notes
    elsif !required(:parent)
      Note.all
    end
  end
end
```

This allows you to easily access the set of notes that make sense given the URL, e.g.:


```ruby
class NotesController < ApplicationController
  def index
    # notes is basically equivalent to @group.notes, @person.notes, or just Note,
    # for the urls /groups/1/notes, /people/1/notes, or /notes (respectively).
    @notes = notes.order(:created_at).page(params[:page])
  end
end
```

For parent resources, `current_user.can_read?(@parent)` is consulted. If false, then an `LoadAndAuthorizeResource::AccessDenied` error is raised.

If none of the parent IDs are present, e.g. `person_id` and `group_id` are both absent in `params`, then a `LoadAndAuthorizeResource::ParameterMissing` exception is raised.

### Specifying Type of Authorization Required

When authorizing a parent resource, you may wish to check a permission other than `:read`. If so, specify the `permit` option:

```ruby
class NotesController < ApplicationController
  load_and_authorize_parent :person, permit: :edit
end
```

Instead of asking `current_user.can_read?(person)`, LAAR will ask `current_user.can_edit?(person)`.

### Shallow (Optional) Routes

You can make the parent loading and authorization optional:

```ruby
class NotesController < ApplicationController
  load_and_authorize_parent :person, :group, optional: true
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
  rescue_from 'LoadAndAuthorizeResource::AccessDenied', 'LoadAndAuthorizeResource::ParameterMissing' do |exception|
    render text: 'not authorized', status: :forbidden
  end
end
```

## Author

Made with ❤ by [Tim Morgan](http://timmorgan.org).

Licensed under MIT license. Please use it, fork it, make it more awesome.
