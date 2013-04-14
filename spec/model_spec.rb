require 'spec_helper'

describe TestNewsletter do
  before(:each) do
    # Empty deliveries
    ActionMailer::Base.deliveries = []
    # Ensure config specs doesn't edit current chunks size
    ActsAsNewsletter::Model.emails_chunk_size = EMAILS_CHUNK_SIZE
    @newsletter = TestNewsletter.new
  end

  it "should be initialized as a draft" do
    @newsletter.draft?.should be_true
  end

  it "should transition to ready state when readied switch is se to true" do
    @newsletter.readied = true
    @newsletter.save
    @newsletter.state_name.should eq :ready
  end

  it "should prepare recipients when asked to" do
    @newsletter.written!
    @newsletter.prepare_sending!
    @newsletter.state_name.should eq :sending
    @newsletter.emails.should include("user-0@example.com")
    @newsletter.emails.length.should eq EMAILS_CHUNK_SIZE
    @newsletter.sent_count.should eq 0
    @newsletter.recipients_count.should eq RECIPIENTS_COUNT
  end

  context "Sending" do
    before(:each) do
      @newsletter.written!
      @newsletter.prepare_sending!
    end

    context "emails" do
      it "should contain the next recipients to send emails to" do
        @newsletter.emails.should eq RECIPIENTS_EMAILS.take EMAILS_CHUNK_SIZE
      end

      it "should contain different emails on each sending" do
        first_emails = @newsletter.emails
        @newsletter.send_newsletter!
        second_emails = @newsletter.emails
        second_emails.should_not eq first_emails
      end
    end

    it "should update sent emails counter when a chunk is sent" do
      expected_recipients = @newsletter.emails
      @newsletter.send_newsletter!
      @newsletter.save
      @newsletter.sent_count.should eq EMAILS_CHUNK_SIZE

      actual_recipients = ActionMailer::Base.deliveries.map(&:to).flatten
      expected_recipients.should eq actual_recipients
    end

    it "should send to all recipients and transition to :sent state when called enough times" do
      expected_recipients = @newsletter.available_emails.dup
      3.times { @newsletter.send_newsletter! }
      @newsletter.sent_count.should eq RECIPIENTS_COUNT

      @newsletter.state_name.should eq :sent

      actual_recipients = ActionMailer::Base.deliveries.map(&:to).flatten
      actual_recipients.should eq expected_recipients
    end

  end
end