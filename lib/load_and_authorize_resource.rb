require 'active_support/concern'

module LoadAndAuthorizeResource
  extend ActiveSupport::Concern

  class ParameterMissing < KeyError; end
  class AccessDenied < StandardError; end

  # Controller method names to action verb mapping
  #
  # Other controller methods will use the name of the action, e.g.
  # if your controller action is `rotate`, then it will be assumed
  # to be your verb too: `current_user.can_rotate?(resource)`
  #
  METHOD_TO_ACTION_NAMES = {
    'show'    => 'read',
    'new'     => 'create',
    'create'  => 'create',
    'edit'    => 'update',
    'update'  => 'update',
    'destroy' => 'delete'
  }

  included do
    class_attribute :nested_resource_options
  end

  module ClassMethods

    # Macro sets a before filter to load the parent resource.
    # Pass in one symbol for each potential parent you're nested under.
    #
    # For example, if you have routes:
    #
    #     resources :people do
    #       resources :notes
    #     end
    #
    #     resources :groups do
    #       resources :notes
    #     end
    #
    # ...you can call load_parent like so in your controller:
    #
    #     class NotesController < ApplicationController
    #       load_parent :person, :group
    #     end
    #
    # This will attempt to do the following for each resource, in order:
    #
    # 1. look for `params[:person_id]`
    # 2. if present, call `Person.find(params[:person_id])`
    # 3. set @person
    #
    # If we've exhausted our list of potential parent resources without
    # seeing the needed parameter (:person_id or :group_id), then a
    # {LoadAndAuthorizeResource::ParameterMissing} error is raised.
    #
    # Note: load_parent assumes you've only nested your route a single
    # layer deep, e.g. /parents/1/children/2
    # You're on your own if you want to load multiple nested
    # parents, e.g. /grandfathers/1/parents/2/children/3
    #
    # If you wish to also allow shallow routes (no parent), you can
    # set the `:shallow` option to `true`:
    #
    #     class NotesController < ApplicationController
    #       load_parent :person, :group, shallow: true
    #     end
    #
    # The `:shallow` option is aliased to `:optional` in cases where it
    # sense to think about parent resources that way. Further, you can
    # call the macro more than once should you want to make some
    # optional and some not:
    #
    #     class NotesController < ApplicationController
    #       load_parent :person, :group, optional: true
    #       load_parent :book
    #     end
    #
    # Additionally, a private method is defined with the same name as
    # the resource. The method looks basically like this (if you were
    # to write it yourself):
    #
    #     class NotesController < ApplicationController
    #
    #       private
    #
    #       def notes
    #         if @person
    #           @person.notes.scoped
    #         elsif not required(:person)
    #           Note.scoped
    #         end
    #       end
    #     end
    #
    # You can change the name of this accessor if it is not the same
    # as the resource this controller represents:
    #
    #     class NotesController < ApplicationController
    #       load_parent :group, children: :people
    #     end
    #
    # This will create a private method called "people" that either returns
    # `@group.people.scoped` or Person.scoped (only if @group is optional).
    #
    # @param names [Array<String, Symbol>] one or more names of resources in lower case
    # @option options [Boolean] :optional set to true to allow non-nested routes, e.g. `/notes` in addition to `/people/1/notes`
    # @option options [Boolean] :shallow (alias for :optional)
    # @option options [Boolean] :except controller actions to ignore when applying this filter
    # @option options [Boolean] :only controller actions to apply this filter
    # @option options [String, Symbol] :children name of child accessor (inferred from controller name, e.g. "notes" for the NotesController)
    #
    def load_parent(*names)
      options = names.extract_options!.dup
      required = !(options.delete(:shallow) || options.delete(:optional))
      save_nested_resource_options(:load, names, required: required)
      define_scope_method(names, options.delete(:children))
      before_filter :load_parent, options
    end

    # Macro sets a before filter to authorize the parent resource.
    # Assumes ther resource is already set (in a before filter).
    #
    #     class NotesController < ApplicationController
    #       authorize_parent :group
    #     end
    #
    # If `@group` is not found, or calling `current_user.can_read?(@group)` fails,
    # an {LoadAndAuthorizeResource::AccessDenied} exception will be raised.
    #
    # If the parent resource is optional, and you only want to check authorization
    # if it is set, you can set the `:shallow` option to `true`:
    #
    #     class NotesController < ApplicationController
    #       authorize_parent :group, shallow: true
    #     end
    #
    # @option options [Boolean] :shallow set to true to allow non-nested routes, e.g. `/notes` in addition to `/people/1/notes`
    # @option options [Boolean] :permit set to permission that should be consulted, e.g. :edit, :delete (defaults to :read)
    # @option options [Boolean] :except controller actions to ignore when applying this filter
    # @option options [Boolean] :only controller actions to apply this filter
    #
    def authorize_parent(*names)
      options = names.extract_options!.dup
      required = !(options.delete(:shallow) || options.delete(:optional))
      permit = options.delete(:permit) || :read
      save_nested_resource_options(:auth, names, required: required, permit: permit)
      before_filter :authorize_parent, options
    end

    # A convenience method for calling both `load_parent` and `authorize_parent`
    def load_and_authorize_parent(*names)
      load_parent(*names)
      authorize_parent(*names)
    end

    # Load the resource and set to an instance variable.
    #
    # For example:
    #
    #     class NotesController < ApplicationController
    #       load_resource
    #     end
    #
    # ...automatically finds the note for actions `show`, `edit`, `update`, and `destroy`.
    #
    # For the `new` action, simply instantiates a new resource. For `create`, instantiates and sets attributes to `<resource>_params`.
    #
    # @option options [Boolean] :except controller actions to ignore when applying this filter
    # @option options [Boolean] :only controller actions to apply this filter (default is show, new, create, edit, update, and destroy)
    # @option options [String, Symbol] :children name of child accessor (inferred from controller name, e.g. "notes" for the NotesController)
    #
    def load_resource(options={})
      options = options.dup
      unless options[:only] or options[:except]
        options.reverse_merge!(only: [:show, :new, :create, :edit, :update, :destroy])
      end
      define_scope_method([], options.delete(:children))
      before_filter :load_resource, options
    end

    # Checks authorization on the already-loaded resource.
    #
    # This method calls `current_user.can_<action>?(@resource)` and raises an {LoadAndAuthorizeResource::AccessDenied} exception if the answer is 'no'.
    #
    # @option options [Boolean] :except controller actions to ignore when applying this filter
    # @option options [Boolean] :only controller actions to apply this filter
    #
    def authorize_resource(options={})
      options = options.dup
      unless options[:only] or options[:except]
        options.reverse_merge!(only: [:show, :new, :create, :edit, :update, :destroy])
      end
      before_filter :authorize_resource, options
    end

    # A convenience method for calling both `load_resource` and `authorize_resource`
    def load_and_authorize_resource(options={})
      load_resource(options)
      authorize_resource(options)
    end

    # Returns the name of the resource, in singular form, e.g. "note"
    #
    # By default, this is simply `controller_name.singularize`.
    #
    def resource_name
      controller_name.singularize
    end

    # Returns the name of the resource, in plural form, e.g. "notes"
    #
    # By default, this is simply the `controller_name`.
    #
    def resource_accessor_name
      controller_name
    end

    protected

    # Defines a method with the same name as the resource (`notes` for the NotesController)
    # that returns a scoped relation, either @parent.notes, or Note itself.
    def define_scope_method(parents, name=nil)
      name ||= resource_accessor_name
      self.nested_resource_options ||= {}
      self.nested_resource_options[:accessors] ||= []
      unless self.nested_resource_options[:accessors].include?(name)
        self.nested_resource_options[:accessors] << name
        define_method(name) do
          parents.each do |parent|
            if resource = instance_variable_get("@#{parent}")
              return resource.send(name).scoped
            end
          end
          name.to_s.classify.constantize.scoped
        end
        private(name)
      end
    end

    # Stores groups of names and options (required) on a class attribute on the controller
    def save_nested_resource_options(key, names, options)
      self.nested_resource_options ||= {}
      self.nested_resource_options[key] ||= []
      group = options.merge(resources: names)
      self.nested_resource_options[key] << group
    end
  end

  protected

  # Loop over each parent resource, and try to find a matching parameter.
  # Then lookup the resource using the supplied id.
  def load_parent
    self.class.nested_resource_options[:load].each do |group|
      parent = group[:resources].detect do |key|
        if id = params["#{key}_id".to_sym]
          parent = key.to_s.classify.constantize.find(id)
          instance_variable_set "@#{key}", parent
        end
      end
      verify_shallow_route!(group) unless parent
    end
  end

  # Loads/instantiates the resource object.
  def load_resource
    scope = send(resource_accessor_name)
    if ['new', 'create'].include?(params[:action].to_s)
      resource = scope.new
      if 'create' == params[:action].to_s
        resource.attributes = send("#{resource_name}_params")
      end
    elsif params[:id]
      resource = scope.find(params[:id])
    else
      resource = nil
    end
    instance_variable_set("@#{resource_name}", resource)
  end

  # Verify the current user is authorized to view the parent resource.
  # Assumes that `load_parent` has already been run and that `@parent` is set.
  # If `@parent` is empty and the parent is optional, don't perform any
  # authorization check.
  def authorize_parent
    self.class.nested_resource_options[:auth].each do |group|
      group[:resources].each do |name|
        parent = instance_variable_get("@#{name}")
        if not parent and group[:required]
          raise ParameterMissing.new('parent resource not found')
        end
        if parent
          authorize_resource(parent, group[:permit])
        end
      end
    end
  end

  # Asks the current_user if he/she is authorized to perform the given action.
  def authorize_resource(resource=nil, action=nil)
    resource ||= instance_variable_get("@#{resource_name}")
    action ||= METHOD_TO_ACTION_NAMES[params[:action].to_s] || params[:action].presence
    raise ArgumentError unless resource and action
    unless current_user.send("can_#{action}?", resource)
      raise AccessDenied.new("#{current_user} cannot #{action} #{resource}")
    end
  end

  # Verify this shallow route is allowed, otherwise raise an exception.
  def verify_shallow_route!(group)
    return unless group[:required]
    expected = group[:resources].map { |n| ":#{n}_id" }
    raise ParameterMissing.new(
      "must supply one of #{expected.join(', ')}"
    )
  end

  def resource_name
    self.class.resource_name
  end

  def resource_accessor_name
    self.class.resource_accessor_name
  end
end
