<?php

namespace App\Exceptions;

use Exception;
use Illuminate\Http\JsonResponse;
use App\Support\ApiResponse;

class DomainException extends Exception
{
    protected string $errorCode;
    protected int $statusCode;
    protected ?array $errors;
    protected ?array $extraData;

    public function __construct(
        string $message,
        string $errorCode,
        int $statusCode = 422,
        ?array $errors = null,
        ?array $extraData = null
    ) {
        parent::__construct($message, $statusCode);
        $this->errorCode = $errorCode;
        $this->statusCode = $statusCode;
        $this->errors = $errors;
        $this->extraData = $extraData;
    }

    public function getErrorCode(): string
    {
        return $this->errorCode;
    }

    public function getStatusCode(): int
    {
        return $this->statusCode;
    }

    public function getErrors(): ?array
    {
        return $this->errors;
    }

    public function getExtraData(): ?array
    {
        return $this->extraData;
    }

    public function render(): JsonResponse
    {
        return ApiResponse::error(
            $this->getMessage(),
            $this->errorCode,
            $this->statusCode,
            $this->errors,
            $this->extraData
        );
    }
}
