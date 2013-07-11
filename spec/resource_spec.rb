require_relative './spec_helper'

class Group; end
class Person; end
class Note; end

describe NotesController, type: :controller do

  before do
    @relation = double('relation', scoped: nil)
    @note = double('note', id: 1)
    Note.stub(:scoped).and_return(@relation)
  end

  context 'load resource' do
    controller do
      load_resource

      def note_params
        {title: 'test'}
      end
    end

    before do
      @relation.stub(:find).and_return(@note)
      @relation.stub(:new).and_return(@note)
      @note.stub(:attributes=)
    end

    context 'when called with an id' do
      before do
        get :show, id: @note.id
      end

      it 'finds the resource by id' do
        expect(assigns[:note]).to eq(@note)
      end
    end

    context 'when create is called' do
      before do
        post :create
        @note = assigns[:note]
      end

      it 'instantiates a new resource' do
        expect(@relation).to have_received(:new)
      end

      it 'sets attributes on new resource' do
        expect(@note).to have_received(:attributes=).with({title: 'test'})
      end
    end
  end

  context 'authorize resource' do
    controller do
      before_filter :get_note
      authorize_resource
    end

    before do
      note = @note
      controller.define_singleton_method(:get_note) { @note = note }
    end

    context 'when a non-standard action is called' do
      controller do
        authorize_resource only: :burn

        def burn
          render text: 'rotated'
        end
      end

      before do
        routes.draw { get 'burn' => 'anonymous#burn' }
        user = @user = double('user', can_burn?: true)
        controller.define_singleton_method(:current_user) { user }
        get :burn, id: @note.id
      end

      it 'calls can_<action>? on the user' do
        expect(@user).to have_received(:can_burn?).with(@note)
      end
    end

    context 'user is not authorized' do
      before do
        user = @user = double('user', can_read?: false, can_create?: false)
        controller.define_singleton_method(:current_user) { user }
      end

      context 'when show is called' do
        it 'raises an exception' do
          expect {
            get :show, id: @note.id
          }.to raise_error(LoadAndAuthorizeResource::AccessDenied)
        end

        it 'checkss can_read? on user' do
          get :show, id: @note.id rescue nil
          expect(@user).to have_received(:can_read?)
        end
      end

      context 'when create is called' do
        it 'raises an exception' do
          expect {
            post :create
          }.to raise_error(LoadAndAuthorizeResource::AccessDenied)
        end

        it 'checks can_create? on user' do
          get :create, id: @note.id rescue nil
          expect(@user).to have_received(:can_create?)
        end
      end
    end
  end
end
