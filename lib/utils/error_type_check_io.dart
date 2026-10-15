import 'dart:io';

bool isNetworkException(Object error) =>
    error is SocketException || error is HttpException;
