require 'telegram/bot/routes_helper'

RSpec.describe Telegram::Bot::RoutesHelper do
  let(:bot) { create_bot('bot_token') }
  let(:other_bot) { create_bot('other_token') }
  let(:bots) { {default: bot, other: other_bot} }

  def create_bot(*args)
    Telegram::Bot::Client.new(*args)
  end

  describe '.route_name_for_bot' do
    subject { described_class.route_name_for_bot(input) }
    before { expect(Telegram).to receive(:bots) { bots } }

    context 'when there is only one bot' do
      let(:bots) { {default: bot} }

      context 'for existing bot' do
        let(:input) { bot }
        it { should eq 'telegram_webhook' }
      end

      context 'for non-existing bot' do
        let(:input) { other_bot }
        it { should eq 'telegram_webhook' }
      end
    end

    context 'when there are multiple bots' do
      context 'for existing bot' do
        let(:input) { bot }
        it { should eq 'default_telegram_webhook' }
      end

      context 'for non-existing bot' do
        let(:input) { double(:missing_bot) }
        it { should eq 'telegram_webhook' }
      end
    end
  end

  describe '#telegram_webhooks' do
    subject { mapper.telegram_webhooks(*input) }
    let(:mapper) { double(:mapper).tap { |x| x.extend described_class } }
    let(:bots) { {default: bot, other: other_bot} }
    let(:controller) { double(:controller, name: :controller) }
    let(:other_controller) { double(:other_controller, name: :other_controller) }
    before { allow(Telegram).to receive(:bots) { bots } }

    def assert_routes(*expected) # rubocop:disable AbcSize
      expected.each do |(bot, controller, route_name, options)|
        expect(mapper).to receive(:post) do |path, params|
          expect(path).to eq "telegram/#{bot.token}"
          middleware = params[:to]
          expect(middleware.controller).to eq(controller)
          expect(middleware.bot.token).to eq(bot.token)
          expect(middleware.bot.username).to eq(bot.username)
          expect(params[:as]).to eq route_name
          expect(params).to include(options) if options
        end
      end
      subject
    end

    context 'when called with controller' do
      let(:input) { [controller, option: :val] }

      it 'creates routes for every bot and this controller' do
        assert_routes [bot, controller, 'default_telegram_webhook', option: :val],
                      [other_bot, controller, 'other_telegram_webhook', option: :val]
      end
    end

    context 'when called with hash' do
      let(:input) do
        [
          {
            bot => controller,
            'custom_token' => [other_controller, as: :custom_route, option: :other_val],
            other: controller,
          },
          option: :val,
        ]
      end

      it 'creates routes for every bot and its controller' do
        assert_routes [bot, controller, 'default_telegram_webhook', option: :val],
                      [
                        create_bot('custom_token'),
                        other_controller,
                        :custom_route,
                        option: :other_val,
                      ],
                      [Telegram.bots[:other], controller, 'other_telegram_webhook', option: :val]
      end
    end

    context 'when called with controller and smth castable to bot' do
      let(:input) do
        [
          controller,
          ['custom_token', token: bot.token, username: 'new_name'],
          option: :val,
        ]
      end

      it 'creates routes for every created bot and controller' do
        assert_routes [
          create_bot('custom_token'),
          controller,
          'telegram_webhook',
          option: :val,
        ], [
          create_bot(bot.token, 'new_name'),
          controller,
          'telegram_webhook',
          option: :val,
        ]
      end
    end
  end
end
