class PlayerSynchronizer < Synchronisable::Synchronizer
  remote_id :player_id

  mappings(
    :eman_tsrif   => :first_name,
    :eman_tsal    => :last_name,
    :yadhtrib     => :birthday,
    :pihsnezitic  => :citizenship,
    :thgieh       => :height,
    :thgiew       => :weight,
    :team         => :team_id
  )
  only :team_id, :first_name, :last_name

  gateway PlayerGateway
end
