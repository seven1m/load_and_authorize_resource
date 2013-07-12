require_relative './spec_helper'

class Group; end
class Person; end
class Note; end

describe NotesController, type: :controller do

  before do
    @relation = double('relation', scoped: 'scoped relation')
    Note.stub(:scoped).and_return(@relation)
    @group = double('group', id: 1, notes: @relation, people: @relation)
    Group.stub(:find).and_return(@group)
    @person = double('person', id: 1, notes: @relation)
    Person.stub(:find).and_return(@person)
  end

  context 'load a single parent' do
    controller do
      load_parent :group
    end

    context 'when called with the parent id' do
      before do
        get :index, group_id: @group.id
      end

      it 'sets the parent resource by name' do
        expect(assigns[:group]).to eq(@group)
      end

      it 'defines a child accessor' do
        result = @controller.send(:notes)
        expect(@group).to have_received(:notes)
        # AR internals here, yikes
        # TODO need an adapter for different ORMs
        expect(@relation).to have_received(:scoped)
        expect(result).to eq('scoped relation')
      end
    end

    context 'when called without the parent id' do
      it 'raises an exception' do
        expect { get :index }.to raise_error(LoadAndAuthorizeResource::ParameterMissing)
      end
    end
  end

  context 'load more than one parent' do
    controller do
      load_parent :group, :person
    end

    context 'when called with the first parent id' do
      before do
        get :index, group_id: @group.id
      end

      it 'sets the parent resource' do
        expect(assigns[:group]).to eq(@group)
      end
    end

    context 'when called with the second parent id' do
      before do
        get :index, person_id: @person.id
      end

      it 'sets the parent resource' do
        expect(assigns[:person]).to eq(@person)
      end
    end
  end

  context 'load_parent with shallow option' do
    controller do
      load_parent :group, :person, shallow: true
    end

    context 'when called without the parent id' do
      before do
        get :index
      end

      it 'loads no parent' do
        expect(assigns[:group]).to be_nil
        expect(assigns[:person]).to be_nil
      end

      it 'defines a child accessor' do
        @controller.send(:notes)
        expect(Note).to have_received(:scoped)
      end
    end
  end

  context 'load_parent with optional option' do
    controller do
      load_parent :group, :person, optional: true
    end

    context 'when called without the parent id' do
      before do
        get :index
      end

      it 'loads no parent' do
        expect(assigns[:group]).to be_nil
        expect(assigns[:person]).to be_nil
      end

      it 'defines a child accessor' do
        @controller.send(:notes)
        expect(Note).to have_received(:scoped)
      end
    end
  end

  context 'load_parent with children option' do
    controller do
      load_parent :group, children: :people
    end

    context 'when called with the parent id' do
      before do
        get :index, group_id: @group.id
      end

      it 'sets the parent resource' do
        expect(assigns[:group]).to eq(@group)
      end

      it 'defines the specified child accessor' do
        @controller.send(:people)
        expect(@group).to have_received(:people)
      end
    end
  end

  context 'call load_parent more than once, with different options' do
    controller do
      load_parent :group
      load_parent :person, optional: true
    end

    context 'when called with the both parent ids' do
      before do
        get :index, group_id: @group.id, person_id: @person.id
      end

      it 'sets both parent resources' do
        expect(assigns[:group]).to eq(@group)
        expect(assigns[:parent]).to eq(@parent)
      end
    end

    context 'when called without the required parent id' do
      it 'raises an exception' do
        expect { get :index }.to raise_error(LoadAndAuthorizeResource::ParameterMissing)
      end
    end

    context 'when called with the required parent id only' do
      before do
        get :index, group_id: @group.id
      end

      it 'sets the parent resource' do
        expect(assigns[:group]).to eq(@group)
      end
    end

    context 'when called without a parent id' do
      it 'raises an exception' do
        expect { get :index }.to raise_error(LoadAndAuthorizeResource::ParameterMissing)
      end
    end
  end

  context 'authorize parent' do
    controller do
      before_filter :get_group
      authorize_parent :group

      def get_group
      end
    end

    context 'when called with the parent id' do
      context 'parent not found' do
        it 'raises a missing parameter exception' do
          expect {
            get :index, group_id: @group.id
          }.to raise_error(LoadAndAuthorizeResource::ParameterMissing)
        end
      end

      context 'parent found and user not authorized' do
        before do
          group = double('group')
          controller.define_singleton_method(:get_group) { @group = group }
          user = double('user', can_read?: false)
          controller.define_singleton_method(:current_user) { user }
        end

        it 'raises an unauthorized exception' do
          expect {
            get :index
          }.to raise_error(LoadAndAuthorizeResource::AccessDenied)
        end
      end

      context 'parent found and user is authorized' do
        before do
          group = double('group')
          controller.define_singleton_method(:get_group) { @group = group }
          user = double('user', can_read?: true)
          controller.define_singleton_method(:current_user) { user }
        end

        setup do
          get :index
        end

        it 'does nothing' do
          expect(response).to be_success
        end
      end
    end
  end
end
