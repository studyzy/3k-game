package entities

// Alliance 同盟，对应 scripts/data/alliance.gd
type Alliance struct {
	CountryId int `json:"countryId"`
	Months    int `json:"months"`
}
