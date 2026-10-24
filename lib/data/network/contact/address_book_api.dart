import 'package:twake_chat/data/network/interceptor/dynamic_url_interceptor.dart';
import 'package:twake_chat/modules/brancardage/brancardage_api.dart';
import 'package:twake_chat/data/model/addressbook/address_book_request.dart';
import 'package:twake_chat/data/model/addressbook/address_book_response.dart';
import 'package:twake_chat/data/network/dio_client.dart';
import 'package:twake_chat/data/network/tom_endpoint.dart';
import 'package:twake_chat/di/global/get_it_initializer.dart';
import 'package:twake_chat/di/global/network_di.dart';

class AddressBookApi {
  final DioClient _client = getIt.get<DioClient>(
    instanceName: NetworkDI.tomDioClientName,
  );

  static const chatPorterContactsEnabled = bool.fromEnvironment(
    'CHATPORTER_CONTACTS_ENABLED',
  );

  static String resolvePath({
    required bool tomConfigured,
    required bool recipeEnabled,
  }) {
    if (!tomConfigured && recipeEnabled) {
      return '${BrancardageApi.base}/api/contacts';
    }
    return TomEndpoint.addressbookServicePath.path;
  }

  String get _path => resolvePath(
    tomConfigured:
        getIt
            .get<DynamicUrlInterceptors>(
              instanceName: NetworkDI.tomServerUrlInterceptorName,
            )
            .baseUrl !=
        null,
    recipeEnabled: chatPorterContactsEnabled,
  );

  Future<AddressbookResponse> getAddressBook() async {
    final response = await _client
        .get(_path)
        .onError((error, stackTrace) => throw Exception(error));

    return AddressbookResponse.fromJson(response);
  }

  Future<AddressbookResponse> updateAddressBook({
    required AddressBookRequest request,
  }) async {
    final response = await _client
        .postToGetBody(_path, data: request.toJson())
        .onError((error, stackTrace) => throw Exception(error));

    return AddressbookResponse.fromJson(response);
  }
}
