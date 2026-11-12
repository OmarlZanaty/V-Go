namespace Masafet_Elseka.Application.DTOs.AuthDTOs
{
    // IdToken is Apple's identityToken. FullName comes from the device and may
    // be supplied on the first call as a suggestion for the profile form.
    public class AppleTokenLoginDTO : GoogleTokenLoginDTO { }

    public class AppleTokenDriverDTO : GoogleTokenDriverDTO { }
}
