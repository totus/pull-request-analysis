class Repository < ApplicationRecord
  has_many :pull_requests, dependent: :destroy

  validates :owner, :name, :full_name, presence: true
  validates :full_name, uniqueness: true
  validate :full_name_format

  before_validation :normalize_names

  scope :alphabetical, -> { order(:full_name) }

  private

  def normalize_names
    return if full_name.blank?

    self.full_name = full_name.strip.downcase
    self.owner, self.name = full_name.split("/", 2)
  end

  def full_name_format
    return if owner.present? && name.present?

    errors.add(:full_name, "must be in the format owner/repository")
  end
end
