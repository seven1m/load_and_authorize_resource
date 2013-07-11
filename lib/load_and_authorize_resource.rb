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
    # 3. set @person and @parent
    #
    # If we've exhausted our list of potential parent resources without
    # seeing the needed parameter (:person_id or :group_id), then a
    # LoadAndAuthorizeResource::ParameterMissing error is raised.
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
    # Additionally, a private method is defined with the same name as
    # the resource. The method looks basically like this:
    #
    #     class NotesController < ApplicationController
    #
    #       private
    #
    #       def notes
    #         if @parent
    #           @parent.notes.scoped
    #         else
    #           Note.scoped
    #         end
    #       end
    #     end
    #
    def load_parent(*names)
      options = names.extract_options!.dup
      self.nested_resource_options ||= {}
      self.nested_resource_options[:load] = {
        options: {shallow: options.delete(:shallow)},
        resources: names
      }
      define_scope_method(options.delete(:children))
      before_filter :load_parent, options
    end

    # Macro sets a before filter to authorize the parent resource.
    # Assumes there is a `@parent` variable.
    #
    #     class NotesController < ApplicationController
    #       authorize_parent
    #     end
    #
    # If `@parent` is not found, or calling `current_user.can_read?(@parent)` fails,
    # an exception will be raised.
    #
    # If the parent resource is optional, and you only want to check authorization
    # if it is set, you can set the `:shallow` option to `true`:
    #
    #     class NotesController < ApplicationController
    #       authorize_parent shallow: true
    #     end
    #
    def authorize_parent(options={})
      options = options.dup
      self.nested_resource_options ||= {}
      self.nested_resource_options[:auth] = {
        options: {shallow: options.delete(:shallow)}
      }
      before_filter :authorize_parent, options
    end

    # A convenience method for calling both `load_parent` and `authorize_parent`
    def load_and_authorize_parent(*names)
      load_parent(*names)
      authorize_parent(names.extract_options!)
    end

    # Load the resource and set to an instance variable.
    #
    # For example:
    #
    #     class NotesController < ApplicationController
    #       load_resource
    #     end
    #
    # ...automatically finds the note for actions
    # `show`, `edit`, `update`, and `destroy`.
    #
    # For the `new` action, simply instantiates a
    # new resource. For `create`, instantiates and
    # sets attributes to `<resource>_params`.
    #
    def load_resource(options={})
      options = options.dup
      unless options[:only] or options[:except]
        options.reverse_merge!(only: [:show, :new, :create, :edit, :update, :destroy])
      end
      define_scope_method(options.delete(:children))
      before_filter :load_resource, options
    end

    # Checks authorization on resource by calling one of:
    #
    # * `current_user.can_read?(@note)`
    # * `current_user.can_create?(@note)`
    # * `current_user.can_update?(@note)`
    # * `current_user.can_delete?(@note)`
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
    def resource_name
      controller_name.singularize
    end

    # Returns the name of the resource, in plural form, e.g. "notes"
    #
    # By default, this is simply the `controller_name`.
    def resource_accessor_name
      controller_name
    end

    protected

    # Defines a method with the same name as the resource (`notes` for the NotesController)
    # that returns a scoped relation, either @parent.notes, or Note itself.
    def define_scope_method(name=nil)
      name ||= resource_accessor_name
      define_method(name) do
        if @parent
          @parent.send(name).scoped
        else
          name.classify.constantize.scoped
        end
      end
      private(name)
    end
  end

  protected

  # Loop over each parent resource, and try to find a matching parameter.
  # Then lookup the resource using the supplied id.
  def load_parent
    keys = self.class.nested_resource_options[:load][:resources]
    parent = keys.detect do |key|
      if id = params["#{key}_id".to_sym]
        @parent = key.to_s.classify.constantize.find(id)
        instance_variable_set "@#{key}", @parent
      end
    end
    verify_shallow_route! unless @parent
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
  # If `@parent` is empty and the `shallow` option is enabled, don't
  # perform any authorization check.
  def authorize_parent
    if not @parent and not self.class.nested_resource_options[:auth][:options][:shallow]
      raise ParameterMissing.new('parent resource not found')
    end
    if @parent
      authorize_resource(@parent, :read)
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
  def verify_shallow_route!
    return if self.class.nested_resource_options[:load][:options][:shallow]
    expected = self.class.nested_resource_options[:load][:resources].map { |n| ":#{n}_id" }
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
