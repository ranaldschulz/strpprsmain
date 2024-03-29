class Booking < ActiveRecord::Base

  include AASM
  include TokenGenerator
  include Booking::States
  include Booking::Jobs

  extend FriendlyId
  friendly_id :token, slug_column: :token, use: [:slugged, :finders]

  acts_as_paranoid

  monetize :total_cents, :fee_cents, :amount_cents,
    allow_nil: false,
    numericality: {
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 1000000
    }

  attr_accessor :start_time, :end_time

  belongs_to :performer, class_name: 'User'
  belongs_to :user
  belongs_to :service
  belongs_to :event_type
  belongs_to :venue_type
  belongs_to :address
  has_one :payment, as: :payable, dependent: :destroy
  has_one :transference
  has_many :extensions, class_name: 'BookingExtension', dependent: :destroy

  delegate :booking_price, :price_cents, to: :service

  accepts_nested_attributes_for :address
  accepts_nested_attributes_for :payment

  validates_presence_of :performer, :user, :service, :event_type, :venue_type, :entry_instructions,
    :parking_instructions, :special_info, on: :create
  validates :number_of_guests, presence: true, numericality: { only_integer: true, greater_than: 0 }, on: :create
  validates :hours, presence: true, numericality: { only_integer: true, greater_than: 0 }, on: :create
  validates_datetime :start_at, after: lambda { 2.hour.from_now }, on: :create
  validates_datetime :end_at, after: :start_at, on: :create

  scope :by_date, ->(time) { where('(start_at BETWEEN ? AND ?) OR (end_at BETWEEN ? AND ?)', time, time.end_of_day, time, time.end_of_day) }
  scope :recent, -> { order(:start_at) }

  before_validation :prepare, unless: 'start_time.blank?'

  def self.perform_async(id, action)
    return if (booking = find(id)).nil?
    booking.send action
  end

  def current_state
    aasm.current_state
  end

  def payable?
    service && performer&.payment_ready?
  end

  def viewable?
    current_state.in? %i(pending accepted paid completed)
  end

  def editable?
    current_state.in? %i(scheduling address payment)
  end

  def destroyable?
    current_state.in? %i(canceled declined)
  end

  def extendable?
    performer.available?(end_at, user.time_zone)
  end

  def address_attributes=(attrs)
    if (addr = Address.from_attributes(attrs)).persisted?
      self.address = addr
    else
      errors.add :base, addr.errors.full_mesages.join(' ')
    end
  end

  def transfer_payment
    if transference
      true
    else
      create_transference
    end
  end

  def process_payment
    payment.process!
  end

  def metadata
    "bk#{token}"
  end

  def description
    "Payment on #{service.slug}"
  end

  def total_with_extensions
    (total_cents + extensions.paid.sum(:total_cents)) / 100
  end

  def complete
    return unless may_complete?
    complete!
    notify
  end

  private

  def prepare
    beginning_of_day = start_at.in_time_zone(ActiveSupport::TimeZone[user.time_zone]).beginning_of_day
    self.start_at = beginning_of_day + start_time.to_i.hours
    self.total_hours = hours
    self.end_at = self.start_at + hours.to_i.hours
    self.total_cents = booking_price * 100 * hours
    self.fee_cents = (price_cents * (Setting.commission_from_seller.to_f) / 100 * hours).round
    self.amount_cents = total_cents - fee_cents
    self.currency = 'usd'
    self.verification_code = rand(1000...9999)
  end
end
